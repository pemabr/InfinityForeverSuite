local frames, commands, warnings, db = {}, {}, {}, {}
local secret, combat, guid, count, inRaid, keyDown = {}, false, nil, 2, false, false
local health, maximum = { player = 80, party1 = 50, raid1 = 90, raid2 = 30 }, 100
local widget = {}
local function Protected(frame)
	if combat and frame.secure then error("protected frame changed during combat") end
end
function widget:RegisterEvent(event) self.events[event] = true end
function widget:UnregisterEvent(event) self.events[event] = nil end
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text or "" end
function widget:SetAttribute(key, value) Protected(self); self.attributes[key] = value end
function widget:RegisterForClicks(value) Protected(self); self.clicks = value end
function widget:SetPoint(...) Protected(self); self.point = {...} end
function widget:ClearAllPoints() Protected(self) end
function widget:SetScale(value) Protected(self); self.scale = value end
function widget:Show() Protected(self); self.shown = true end
function widget:Hide() Protected(self); self.shown = false end
function widget:IsShown() return self.shown end
function widget:SetChecked(value) self.checked = not not value end
function widget:GetChecked() return self.checked end
function widget:SetValue(value) self.value = value end
function widget:SetMinMaxValues(min, max) self.minimum, self.maximum = min, max end
local meta = { __index = function(_, key) return widget[key] or function() end end }
function CreateFrame(_, name, parent, template)
	if name then assert(not _G[name], "duplicate frame: " .. name) end
	local secure = not not (template and template:find("SecureUnitButtonTemplate", 1, true))
	if combat and secure then error("secure frame created during combat") end
	local frame = setmetatable({ events = {}, scripts = {}, attributes = {}, parent = parent, shown = true, secure = secure }, meta)
	if name then _G[name] = frame end
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
BackdropTemplateMixin = {}
issecretvalue = function(value) return value == secret end
InCombatLockdown = function() return combat end
UnitGUID = function() return guid end
UnitName = function(unit) return unit == "party1" and "Healer" or unit end
UnitHealth = function(unit) return health[unit] end
UnitHealthMax = function() return maximum end
GetNumGroupMembers = function() return count end
IsInRaid = function() return inRaid end
GetCVarBool = function() return keyDown end
InfinityCore = { GetDatabase = function(_, name) assert(name == "InfinityHealer"); return db end }
InfinityUtils = {
	Info = function() end,
	Warning = function(_, message) warnings[#warnings + 1] = message end,
}
InfinityMessaging = { Publish = function() end }
INFINITY_EVENTS = { FEATURE_ENABLED = "enabled" }
InfinityCommandRegistry = { RegisterCommand = function(_, name, callback) commands[name] = callback; return true end }
local suiteCategory, registered = {}, {}
InfinitySettingsPanel = { blizzardCategory = suiteCategory, blizzardPanel = {} }
Settings = {
	RegisterCanvasLayoutCategory = function(panel, name) return { panel = panel, name = name } end,
	RegisterAddOnCategory = function(category) registered.category = category end,
	RegisterCanvasLayoutSubcategory = function(parent, panel, name)
		registered.parent = parent
		registered.category = { panel = panel, name = name }
		return registered.category
	end,
}
dofile("InfinityCore\\UI\\UIFramework.lua")
SlashCmdList = {}
for line in io.lines("InfinityHealer\\InfinityHealer.toc") do
	if line:match("%.lua%s*$") and not line:match("^%s*#") then
		dofile("InfinityHealer\\" .. line:match("^%s*(.-)%s*$"))
	end
end
local loader = frames[#frames]
loader.scripts.OnEvent(loader, "ADDON_LOADED", "InfinityHealer")
assert(not commands.healer and #warnings == 1)
guid = "Player-1"
loader.scripts.OnEvent(loader, "PLAYER_ENTERING_WORLD")
assert(commands.healer and not loader.events.PLAYER_ENTERING_WORLD)
assert(registered.parent == suiteCategory and InfinityGroupStatus.settingsCategory == registered.category)
assert(not InfinityGroupStatus.settingsToggle:GetChecked())
InfinityGroupStatus.settingsToggle:SetChecked(true)
InfinityGroupStatus.settingsToggle.scripts.OnClick(InfinityGroupStatus.settingsToggle)
assert(not InfinityGroupStatus.settingsToggle:GetChecked() and not db.characters[guid].groupSharing)
db.characters[guid].groupSharing = true
InfinityGroupStatus.settingsPanel.scripts.OnShow()
assert(InfinityGroupStatus.settingsToggle:GetChecked())
db.characters[guid].groupSharing = false
InfinityGroupStatus.settingsPanel.scripts.OnShow()
assert(not InfinityGroupStatus.settingsToggle:GetChecked())
local healer = InfinityHealer
local player, party = healer.frames.player, healer.frames.party1
assert(player and party and player:IsShown() and party:IsShown())
assert(player.attributes.unit == "player" and player.attributes.type1 == "target")
assert(player.attributes.type2 == nil and player.clicks == "AnyUp")
assert(party.nameText.text == "Healer" and party.healthText.text == "50%")
commands.healer({"bind", "right", "12345"})
assert(player.attributes.type2 == "spell" and player.attributes.spell2 == 12345)
assert(db.characters[guid].bindings.right == 12345)
commands.healer({"bind", "shift-right", "456"})
assert(party.attributes["shift-type2"] == "spell" and party.attributes["shift-spell2"] == 456)
commands.healer({"bind", "right", "invalid"})
assert(player.attributes.spell2 == 12345)
commands.healer({})
assert(InfinityHealerUI.mainWindow:IsShown())
local ui = InfinityHealerUI.mainWindow
assert(ui.rows[3].data.text:find("12345", 1, true))
InfinityHealerUI.input:SetText("246")
ui.rows[3].scripts.OnClick(ui.rows[3])
assert(db.characters[guid].bindings.right == 246 and player.attributes.spell2 == 246)
InfinityHealerUI.input:SetText("not a spell")
ui.rows[3].scripts.OnClick(ui.rows[3])
assert(db.characters[guid].bindings.right == 246 and warnings[#warnings]:find("valid spell", 1, true))
InfinityHealerUI.input:SetText("1.25")
InfinityHealerUI.scaleButton.scripts.OnClick()
assert(db.characters[guid].scale == 1.25 and player.scale == 1.25)
InfinityHealerUI.input:SetText("1")
InfinityHealerUI.scaleButton.scripts.OnClick()
InfinityHealerUI.input:SetText("12345")
ui.rows[3].scripts.OnClick(ui.rows[3])
commands.healer({ "group", "on" })
assert(not db.characters[guid].groupSharing and warnings[#warnings]:find("unavailable", 1, true))
commands.healer({ "group", "sync" })
assert(warnings[#warnings]:find("Enable", 1, true))
commands.healer({ "watch", "12345" })
assert(db.characters[guid].groupWatch[12345])
commands.healer({ "unwatch", "12345" })
assert(not db.characters[guid].groupWatch[12345])
combat, inRaid, count = true, true, 2
health.party1, maximum = secret, secret
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "UNIT_HEALTH", "party1")
assert(party.healthBar.value == secret and party.healthBar.maximum == secret and party.healthText.text == "?")
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "GROUP_ROSTER_UPDATE")
assert(healer.pending and player:IsShown() and not healer.frames.raid1)
assert(party.nameText.text == "Roster changed" and party.healthBar.value == 0)
InfinityHealerUI.input:SetText("999")
ui.rows[3].scripts.OnClick(ui.rows[3])
assert(db.characters[guid].bindings.right == 999 and player.attributes.spell2 == 12345)
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "UNIT_HEALTH", "party1")
assert(party.nameText.text == "Roster changed" and party.healthText.text == "")
InfinityHealerUI.input:SetText("1.5")
InfinityHealerUI.scaleButton.scripts.OnClick()
assert(db.characters[guid].scale == 1.5 and player.scale == 1)
combat, maximum, keyDown = false, 100, true
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "PLAYER_REGEN_ENABLED")
assert(not healer.pending and not player:IsShown())
assert(healer.frames.raid1:IsShown() and healer.frames.raid1.attributes.spell2 == 999)
assert(healer.frames.raid1.scale == 1.5 and healer.frames.raid1.clicks == "AnyDown")
InfinityHealerUI.input:SetText("clear")
ui.rows[3].scripts.OnClick(ui.rows[3])
assert(healer.frames.raid1.attributes.type2 == nil and healer.frames.raid1.attributes.spell2 == nil)
commands.healer({"scale", "5"})
assert(db.characters[guid].scale == 1.5)
count, inRaid = 0, false
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "GROUP_ROSTER_UPDATE")
assert(not healer.frames.raid1:IsShown())
count, inRaid = 2, false
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "GROUP_ROSTER_UPDATE")
assert(healer.frames.player == player and player:IsShown())
inRaid = secret
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "GROUP_ROSTER_UPDATE")
assert(not player:IsShown() and healer.rosterPending and warnings[#warnings]:find("protected", 1, true))
inRaid = false
healer.eventFrame.scripts.OnEvent(healer.eventFrame, "GROUP_ROSTER_UPDATE")
assert(player:IsShown() and not healer.rosterPending and not healer.pending)
print("healer_frames: all tests passed")
