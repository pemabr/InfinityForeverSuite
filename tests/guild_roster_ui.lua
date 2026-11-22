local frames, warnings = {}, {}
local widget = {}
function widget:SetScript(event, callback) self.scripts[event] = callback end
function widget:CreateFontString() return CreateFrame("FontString", nil, self) end
function widget:CreateTexture() return CreateFrame("Texture", nil, self) end
function widget:SetText(text) self.text = text end
function widget:GetText() return self.text or "" end
function widget:Show() self.shown = true end
function widget:Hide() self.shown = false end
function widget:IsShown() return self.shown end
local meta = { __index = function(_, key)
	if key == "selected" then return nil end
	return widget[key] or function() end
end }
function CreateFrame(_, _, parent)
	local frame = setmetatable({ parent = parent, scripts = {}, shown = true }, meta)
	frames[#frames + 1] = frame
	return frame
end
UIParent = CreateFrame("Frame")
InfinityUtils = {
	Warning = function(_, message) warnings[#warnings + 1] = message end,
	ClearContainer = function(_, parent)
		for _, child in ipairs(frames) do if child.parent == parent then child:Hide() end end
	end,
}
local tooltip = {}
GameTooltip = tooltip
function tooltip:SetOwner(owner) self.owner = owner end
function tooltip:SetText(text) self.text = text end
function tooltip:AddLine(text) self.description = text end
function tooltip:Show() self.shown = true end
function tooltip:Hide() self.shown = false end
local guildName = "Guild"
GetGuildInfo = function() return guildName end
local members = {
	{ name = "Bob", fullName = "Bob-Other", rank = "Member", class = "PRIEST", level = 50, active = false },
	{ name = "Alice", fullName = "Alice-Realm", rank = "Master", class = "MAGE", level = 60, active = true },
}
local requested, scanned = 0, 0
InfinityGuildRoster = {
	guilds = { Guild = {} },
	GetGuildMembers = function() return members end,
	RequestRoster = function() requested = requested + 1 end,
	ScanGuildRoster = function() scanned = scanned + 1 end,
}
dofile("InfinityCore\\UI\\UIFramework.lua")
dofile("InfinityGuild\\UI\\MainUI.lua")
local frame = { contentArea = CreateFrame("Frame") }
InfinityGuildUI:ShowTab(frame, "roster")
local view = frame.rosterView
assert(view.summary.text == "Guild | 2 members | 1 online")
assert(view.rows[1].member.name == "Alice" and view.rows[2].member.name == "Bob")
assert(not view.empty:IsShown())
view.rows[2].scripts.OnEnter(view.rows[2])
assert(tooltip.shown and tooltip.text == "Bob-Other")
view.rows[2].scripts.OnLeave()
assert(not tooltip.shown)
view.rows[2].scripts.OnClick(view.rows[2])
assert(view.detail.text:find("Bob", 1, true) and view.detail.text:find("Offline", 1, true))
view.bags.scripts.OnClick()
assert(warnings[#warnings]:find("Infinity Inventory", 1, true))
local opened
InfinityInventoryUI = { OpenGuildMember = function(_, name) opened = name end }
view.bags.scripts.OnClick()
assert(opened == "Bob-Other")
view.bags.scripts.OnEnter(view.bags)
assert(tooltip.shown and tooltip.description:find("voluntarily", 1, true))
view.bags.scripts.OnLeave()
assert(not tooltip.shown)
view.search:SetText("mage")
view.search.scripts.OnTextChanged()
assert(view.rows[1].member.name == "Alice" and not view.rows[2]:IsShown())
assert(view.selected.name == "Bob")
view.search:SetText("nomatch")
view.search.scripts.OnTextChanged()
assert(view.empty:IsShown() and not view.rows[1]:IsShown())
view.search:SetText("")
view.search.scripts.OnTextChanged()
local previous = #frames
InfinityGuildUI:ShowTab(frame, "roster")
assert(frame.rosterView == view and #frames == previous and view.selected.name == "Bob")
for _, item in ipairs(frames) do
	if item.parent == view and item.text == "Refresh Roster" then item.scripts.OnClick() end
end
assert(requested == 1 and scanned == 1)
members = { members[2] }
InfinityGuildUI:RefreshRoster(frame)
assert(not view.selected and view.detail.text == "Select a guild member.")
guildName = nil
InfinityGuildUI:RefreshRoster(frame)
assert(view.summary.text == "You are not in a guild." and view.empty:IsShown())
print("guild_roster_ui: all tests passed")
