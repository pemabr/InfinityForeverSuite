local current, now, timers, packets, sent, warnings, identityCalls = nil, 100, {}, {}, {}, {}, 0
local clients, secret, buttons = {}, {}, {}
local members, raid, instance = { "Alice", "Bob" }, false, false
issecretvalue = function(value) return rawequal(value, secret) end
GetTime = function() return now end
GetNormalizedRealmName = function() return "Realm" end
GetNumGroupMembers = function() return #members end
IsInRaid = function() return raid end
LE_PARTY_CATEGORY_INSTANCE = 1
IsInGroup = function(category)
	if category == LE_PARTY_CATEGORY_INSTANCE then return instance end
	return #members > 0
end
UnitFullName = function(unit)
	identityCalls = identityCalls + 1
	local name
	if unit == "player" then name = current.name
	elseif unit:match("^party") then
		local index = tonumber(unit:match("%d+"))
		for _, candidate in ipairs(members) do
			if candidate ~= current.name then
				index = index - 1
				if index == 0 then name = candidate; break end
			end
		end
	elseif unit:match("^raid") then name = members[tonumber(unit:match("%d+"))] end
	if name then return name, "Realm" end
end
function CreateFrame()
	return {
		events = {}, scripts = {},
		RegisterEvent = function(self, event) self.events[event] = true end,
		SetScript = function(self, event, callback) self.scripts[event], self.callback = callback, callback end,
		CreateFontString = function() return CreateFrame() end,
		SetPoint = function() end,
		SetSize = function() end,
		SetWidth = function() end,
		SetJustifyH = function() end,
		SetText = function(self, text) self.text = text end,
		GetText = function(self) return self.text or "" end,
		SetAutoFocus = function() end,
		SetMaxLetters = function() end,
		SetChecked = function(self, value) self.checked = not not value end,
		GetChecked = function(self) return self.checked end,
	}
end
local suite = {}
InfinitySettingsPanel = { blizzardCategory = suite, blizzardPanel = {} }
Settings = {
	RegisterCanvasLayoutCategory = function(panel) return { panel = panel } end,
	RegisterAddOnCategory = function() end,
	RegisterCanvasLayoutSubcategory = function(parent, panel)
		assert(parent == suite)
		return { panel = panel }
	end,
}
C_Timer = { After = function(delay, callback)
	timers[#timers + 1] = { when = now + delay, callback = callback, client = current }
end }
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix) assert(prefix == "InfinityGrp1"); return 0 end,
	SendAddonMessage = function(prefix, message, channel)
		assert(prefix == "InfinityGrp1" and #message <= 240)
		if current.failure then
			local failure = current.failure
			current.failure = nil
			return failure
		end
		local packet = { sender = current.name .. "-Realm", message = message, channel = channel }
		packets[#packets + 1], sent[#sent + 1] = packet, packet
		return 0
	end,
}
C_Spell = {
	GetSpellCooldown = function(id)
		if id == 61304 then return { startTime = 0, duration = 0, isEnabled = true, modRate = 1 } end
		return current.cooldowns[id]
	end,
	GetSpellCharges = function(id) return current.charges[id] end,
	GetSpellInfo = function(id) return { name = "Spell " .. id } end,
}
C_UnitAuras = {
	GetAuraDataByIndex = function(unit, index, filter)
		assert(unit == "player")
		return current.auras[filter][index]
	end,
}
InfinityUtils = { Warning = function(_, text) warnings[#warnings + 1] = text end }
InfinityUIFramework = {
	CreateListWindow = function()
		return {
			shown = false, status = { SetText = function(self, text) self.text = text end },
			IsShown = function(self) return self.shown end,
			Show = function(self) self.shown = true end,
			Hide = function(self) self.shown = false end,
			SetItems = function(self, rows) self.rows = rows end,
		}
	end,
	CreateButton = function(_, _, _, _, _, callback)
		local button = { SetPoint = function() end, callback = callback }
		buttons[#buttons + 1] = button
		return button
	end,
}
local function Use(client)
	current = client
	InfinityGroupStatus = client.status
end
for _, name in ipairs({ "Alice", "Bob", "Cara" }) do
	local client = { name = name, cooldowns = {}, charges = {}, auras = { HELPFUL = {}, HARMFUL = {} }, settings = {} }
	clients[name] = client
	Use(client)
	client.status = dofile("InfinityHealer\\Modules\\GroupStatus.lua")
	Use(client)
	client.status:Initialize(client.settings)
	assert(client.status.available and not client.settings.groupSharing)
end
local alice, bob, cara = clients.Alice, clients.Bob, clients.Cara
local function Pump()
	while #packets > 0 do
		local packet = table.remove(packets, 1)
		for _, name in ipairs(members) do
			local client = clients[name]
			Use(client)
			client.status:OnMessage("InfinityGrp1", packet.message, packet.channel, packet.sender)
		end
	end
end
local function Run(seconds)
	local target = now + seconds
	Pump()
	local steps = 0
	while true do
		table.sort(timers, function(a, b) return a.when < b.when end)
		if not timers[1] or timers[1].when > target then break end
		steps = steps + 1
		assert(steps < 10000, "timer loop")
		local timer = table.remove(timers, 1)
		now = timer.when
		Use(timer.client)
		timer.callback()
		Pump()
	end
	now = target
end
local function Event(client, event, ...)
	Use(client)
	client.status.events.callback(nil, event, ...)
end
local function Find(rows, id)
	for _, row in ipairs(rows) do if row.id == id then return row end end
end

alice.cooldowns[10] = { startTime = 100, duration = 20, isEnabled = true, modRate = 1 }
alice.cooldowns[11] = { startTime = 100, duration = 30, isEnabled = true, modRate = 1 }
alice.cooldowns[12] = { startTime = secret, duration = 20, isEnabled = true, modRate = 1 }
alice.cooldowns[99] = { startTime = 100, duration = 40, isEnabled = true, modRate = 2 }
alice.charges[11] = { currentCharges = 1, maxCharges = 2, cooldownStartTime = 100, cooldownDuration = 30, chargeModRate = 1 }
alice.auras.HELPFUL = {
	{ spellId = 200, duration = 20, expirationTime = 120, applications = 2 },
	{ spellId = secret, duration = 10, expirationTime = 110, applications = 1 },
}
alice.auras.HARMFUL = { { spellId = 201, duration = secret, expirationTime = secret, applications = secret } }
Use(alice)
assert(alice.status:Watch(10, true) and alice.status:Watch(11, true) and alice.status:Watch(12, true))
Event(alice, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 99)
assert(not next(alice.status.casts))
Use(alice)
alice.status.settingsToggle:SetChecked(true)
alice.status.settingsToggle.scripts.OnClick(alice.status.settingsToggle)
assert(alice.settings.groupSharing and alice.status.settingsToggle:GetChecked())
Event(alice, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 99)
Run(8)
assert(not next(bob.status.peers) and not cara.settings.groupSharing)
Use(bob)
bob.status.settingsToggle:SetChecked(true)
bob.status.settingsToggle.scripts.OnClick(bob.status.settingsToggle)
assert(bob.settings.groupSharing and bob.status.settingsToggle:GetChecked())
Run(10)
local reports = bob.status.peers["alice-realm"]
assert(reports and reports.C and reports.A and reports.C.partial and reports.A.partial)
assert(Find(reports.C.rows, 10).remaining > 0)
assert(Find(reports.C.rows, 11).charges == 1 and Find(reports.C.rows, 11).maximum == 2)
assert(Find(reports.C.rows, 99) and not Find(reports.C.rows, 12))
assert(Find(reports.A.rows, 200).stacks == "2")
assert(Find(reports.A.rows, 201).remaining == "u" and Find(reports.A.rows, 201).stacks == "u")
Use(alice)
local measured = alice.status:CollectCooldowns()
assert(Find(measured, 99).remaining == math.ceil((140 - now) / 2))
local generation = alice.status.generation
alice.status:Context()
local previousCalls = identityCalls
alice.status:Context()
assert(identityCalls == previousCalls)
Event(alice, "GROUP_ROSTER_UPDATE")
assert(alice.status.generation == generation and identityCalls > previousCalls)
for _, packet in ipairs(sent) do assert(not packet.message:find("secret", 1, true)) end
Use(bob)
bob.status:Toggle()
assert(bob.status.window:IsShown() and bob.status.window.status.text:find("protected", 1, true))
bob.status.watchInput:SetText("7654")
buttons[3].callback()
assert(bob.settings.groupWatch[7654])
buttons[6].callback()
assert(bob.status.showWatches and bob.status.window.rows[1].text:find("7654", 1, true))
bob.status:Refresh()
assert(bob.status.window.rows[1].text:find("7654", 1, true))
bob.status.window.rows[1].onClick()
assert(not bob.settings.groupWatch[7654])
buttons[3].callback()
buttons[4].callback()
assert(not bob.settings.groupWatch[7654])
bob.status.watchInput:SetText(secret)
buttons[3].callback()
assert(warnings[#warnings]:find("valid spell ID", 1, true))
buttons[6].callback()
local foundText = false
for _, row in ipairs(bob.status.window.rows) do
	if row.text:find("Spell 200", 1, true) then foundText = true end
end
assert(foundText)

Use(bob)
local originalAuras = reports.A.rows
reports.A.rows = {}
for id = 1, 80 do reports.A.rows[id] = { kind = "B", id = id, remaining = "p", stacks = "0" } end
bob.status:Refresh()
assert(#bob.status.window.rows == 35 and bob.status.window.status.text:find("Page 1/", 1, true))
buttons[2].callback()
assert(bob.status.window.status.text:find("Page 2/", 1, true) and #bob.status.window.rows > 0)
buttons[1].callback()
reports.A.rows = originalAuras
bob.status:Refresh()
reports.A.received = now - 100
bob.status:Refresh()
local stale = false
for _, row in ipairs(bob.status.window.rows) do if row.text:find("stale", 1, true) then stale = true end end
assert(stale)
reports.A.received = now
local before = reports.A
bob.status:OnMessage("InfinityGrp1", "A~1-9~1~1~0~0~B:999:10:1", "PARTY", "Cara-Realm")
assert(bob.status.peers["alice-realm"].A == before and not bob.status.peers["cara-realm"])
bob.status:OnMessage("InfinityGrp1", "A~1-9~1~2~0~0~B:999:10:1", "PARTY", "Alice-Realm")
assert(bob.status.peers["alice-realm"].A == before)
bob.status:OnMessage("InfinityGrp1", "A~1-9~2~2~0~0~invalid", "PARTY", "Alice-Realm")
assert(bob.status.peers["alice-realm"].A == before)
bob.status:OnMessage("InfinityGrp1", secret, "PARTY", "Alice-Realm")
bob.status:OnMessage("InfinityGrp1", "A~1-11~1~2~0~4~B:999:20:1", "PARTY", "Alice-Realm")
now = now + 2
bob.status:OnMessage("InfinityGrp1", "A~1-11~2~2~0~2~D:998:20:1", "PARTY", "Alice-Realm")
local delayed = bob.status.peers["alice-realm"].A
assert(Find(delayed.rows, 999).remaining == "14" and Find(delayed.rows, 998).remaining == "18")
now = now - 2
bob.status.peers["alice-realm"].A = before

alice.auras.HELPFUL = {}
alice.cooldowns[10] = { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
Event(alice, "UNIT_AURA", "player")
Event(alice, "SPELL_UPDATE_COOLDOWN")
Run(8)
Use(bob)
reports = bob.status.peers["alice-realm"]
assert(not Find(reports.A.rows, 200) and Find(reports.C.rows, 10).remaining == 0)

Use(alice)
alice.auras.HELPFUL, alice.auras.HARMFUL = {}, {}
local expires = now + 20
for index = 1, 80 do
	local aura = { spellId = 999999920 + index, duration = 20,
		expirationTime = expires, applications = 10000 }
	alice.auras.HELPFUL[index], alice.auras.HARMFUL[index] = aura, aura
end
Event(alice, "UNIT_AURA", "player")
Run(28)
Use(bob)
reports = bob.status.peers["alice-realm"]
assert(reports and reports.A and #reports.A.rows == 160 and not reports.A.partial)
assert(tonumber(reports.A.rows[1].remaining) <= math.max(0, math.ceil(expires - reports.A.received)) + 1)
assert(bob.status.window.status.text:find("Page 1/", 1, true))
buttons[2].callback()
assert(bob.status.window.status.text:find("Page 2/", 1, true))
buttons[1].callback()

Use(alice)
local savedCharges = alice.charges[11]
alice.charges[11] = secret
local cooldowns, partial = alice.status:CollectCooldowns()
assert(partial and not Find(cooldowns, 11))
alice.charges[11] = savedCharges
local modernAuras = C_UnitAuras
C_UnitAuras = nil
UnitAura = function(_, index, filter)
	if index == 1 and filter == "HELPFUL" then return "Buff", 1, 2, nil, 10, now + 10, nil, nil, nil, 999 end
end
local legacyAuras, legacyPartial = alice.status:CollectAuras()
assert(not legacyPartial and #legacyAuras == 1 and legacyAuras[1].id == 999)
C_UnitAuras, UnitAura = modernAuras, nil
local modernSpell = C_Spell
C_Spell = nil
GetSpellCooldown = function(id)
	if id == 10 then return 0, 0, 1, 1 end
	return 0, 0, 1, 1
end
GetSpellCharges = function() return nil end
cooldowns = alice.status:CollectCooldowns()
assert(Find(cooldowns, 10).remaining == 0)
C_Spell, GetSpellCooldown, GetSpellCharges = modernSpell, nil, nil

Use(alice)
assert(not alice.status:SetEnabled(false))
local sentBefore = #sent
Event(alice, "UNIT_SPELLCAST_SUCCEEDED", "player", "cast", 99)
Run(6)
assert(not next(alice.status.casts) and #sent == sentBefore)
Use(alice)
assert(alice.status:SetEnabled(true))
raid, members = true, { "Alice", "Bob", "Cara" }
for _, client in pairs(clients) do Event(client, "GROUP_ROSTER_UPDATE") end
Use(cara)
assert(cara.status:SetEnabled(true))
Run(12)
assert(cara.status.peers["alice-realm"] and cara.status.peers["bob-realm"])
assert(sent[#sent].channel == "RAID")

instance = true
for _, client in pairs(clients) do Event(client, "GROUP_ROSTER_UPDATE") end
Run(8)
assert(sent[#sent].channel == "INSTANCE_CHAT")
Use(bob)
assert(bob.status.peers["alice-realm"])
raid = secret
local protectedCount = #sent
Event(alice, "GROUP_ROSTER_UPDATE")
Run(2)
assert(#sent == protectedCount)
raid = true
local packetCount = #sent
members = {}
for _, client in pairs(clients) do Event(client, "GROUP_ROSTER_UPDATE") end
Run(3)
assert(#sent == packetCount and not next(bob.status.peers))

members, raid, instance = { "Alice", "Bob" }, false, false
alice.failure = 8
Event(alice, "GROUP_ROSTER_UPDATE")
Event(bob, "GROUP_ROSTER_UPDATE")
Run(8)
assert(bob.status.peers["alice-realm"])
Use(alice)
alice.failure = 2
assert(alice.status:RequestSync() and alice.status.sendBlocked)
Run(34)
assert(not alice.status.sendBlocked and bob.status.peers["alice-realm"])
Use(alice)
assert(alice.status:Watch(10, false) and not alice.settings.groupWatch[10])
Use(bob)
local beforeSync = bob.status.generation
buttons[5].callback()
assert(bob.status.generation > beforeSync)
local invalid = { groupSharing = true, groupWatch = secret }
local broken = dofile("InfinityHealer\\Modules\\GroupStatus.lua")
assert(broken:Initialize(invalid) == false and rawequal(invalid.groupWatch, secret))
assert(not broken.available and not broken.settings.groupSharing and warnings[#warnings]:find("Invalid saved", 1, true))
assert(not broken:Watch(10, true) and warnings[#warnings]:find("cannot be saved", 1, true))
local topLevel
Settings.RegisterCanvasLayoutSubcategory = nil
Settings.RegisterAddOnCategory = function(category) topLevel = category end
local standalone = dofile("InfinityHealer\\Modules\\GroupStatus.lua")
standalone:Initialize({})
assert(standalone.settingsCategory == topLevel)
Settings = nil
InfinitySettingsPanel.blizzardCategory = InfinitySettingsPanel.blizzardPanel
local legacyPanel
InterfaceOptions_AddCategory = function(panel) legacyPanel = panel end
local legacy = dofile("InfinityHealer\\Modules\\GroupStatus.lua")
legacy:Initialize({})
assert(legacy.settingsCategory == legacyPanel and legacyPanel.parent == "Infinity Suite")
print("group_status: all tests passed")
