local GroupStatus = { prefix = "InfinityGrp1", peers = {}, casts = {}, discovered = {}, sequence = 0 }
_G.InfinityGroupStatus = GroupStatus

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function Integer(value, maximum, zero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (zero and 0 or 1)
		and value <= maximum and value == math.floor(value)
end

local function Number(value, maximum)
	value = Public(value)
	return type(value) == "number" and value == value and value >= 0 and value <= maximum
end

local function UnitKey(unit)
	local name, realm
	if _G.UnitFullName then name, realm = UnitFullName(unit)
	elseif _G.UnitName then name, realm = UnitName(unit) end
	name, realm = Public(name), Public(realm)
	if type(name) ~= "string" or name == "" or #name > 75 or name:find("[%z\1-\31~|]") then return nil end
	local short, suffix = name:match("^([^%-]+)%-(.+)$")
	if short then name, realm = short, suffix end
	if type(realm) ~= "string" or realm == "" then
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" or realm:find("[%z\1-\31~|]") then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function SenderKey(value)
	value = Public(value)
	if type(value) ~= "string" or value == "" or #value > 75 or value:find("[%z\1-\31~|]") then return nil end
	local name, realm = value:match("^([^%-]+)%-(.+)$")
	if not name then
		name = value
		realm = _G.GetNormalizedRealmName and Public(GetNormalizedRealmName())
		if not realm and _G.GetRealmName then realm = Public(GetRealmName()) end
	end
	if type(realm) ~= "string" or realm == "" or realm:find("[%z\1-\31~|]") then return nil end
	return name:lower() .. "-" .. realm:gsub("%s+", ""):lower()
end

local function Clock()
	local now = _G.GetTime and Public(GetTime())
	if Number(now, 1000000000) then return now end
end

function GroupStatus:Warn(key, text)
	self.warnings = self.warnings or {}
	if not self.warnings[key] then
		self.warnings[key] = true
		InfinityUtils:Warning(text, "Healer")
	end
end

function GroupStatus:Context()
	if type(_G.GetNumGroupMembers) ~= "function" or type(_G.IsInRaid) ~= "function" then
		self:Warn("roster", "Group roster API unavailable; group reports paused.")
		return nil
	end
	local count = _G.GetNumGroupMembers and GetNumGroupMembers()
	local raid = _G.IsInRaid and IsInRaid()
	if (_G.issecretvalue and (issecretvalue(count) or issecretvalue(raid)))
		or not Integer(count, 40, true) or (raid ~= nil and raid ~= false and raid ~= true and raid ~= 1)
		or (not raid and count > 5) then
		self:Warn("roster", "Group roster unavailable; group reports paused.")
		return nil
	end
	if count == 0 then return nil end
	local channel = raid and "RAID" or "PARTY"
	if _G.LE_PARTY_CATEGORY_INSTANCE and _G.IsInGroup then
		local instance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
		if _G.issecretvalue and issecretvalue(instance) then
			self:Warn("roster", "Group channel unavailable; group reports paused.")
			return nil
		end
		if instance ~= nil and instance ~= false and instance ~= true and instance ~= 1 then
			self:Warn("roster", "Group channel unavailable; group reports paused.")
			return nil
		end
		if instance == true or instance == 1 then channel = "INSTANCE_CHAT" end
	end
	local now, cached = Clock(), self.rosterCache
	if now and cached and cached.channel == channel and cached.count == count and cached.raid == raid
		and now >= cached.time and now - cached.time < 1 then
		return cached.channel, cached.members, cached.me
	end
	local members, me = {}, UnitKey("player")
	if not me then self:Warn("identity", "Group identity unavailable; group reports paused."); return nil end
	local units = {}
	if raid then
		for i = 1, count do units[#units + 1] = "raid" .. i end
	else
		units[1] = "player"
		for i = 1, count - 1 do units[#units + 1] = "party" .. i end
	end
	local incomplete = false
	for _, unit in ipairs(units) do
		local key = UnitKey(unit)
		if key then members[key] = true else incomplete = true end
	end
	if incomplete then self:Warn("members", "Some group identities are unavailable; their reports are omitted.")
	else self.warnings.members = nil end
	members[me] = true
	self.warnings.roster, self.warnings.identity = nil, nil
	if now then self.rosterCache = { channel = channel, count = count, raid = raid, time = now, members = members, me = me } end
	return channel, members, me
end

local function CooldownAPI(id)
	if _G.C_Spell and type(C_Spell.GetSpellCooldown) == "function" then
		local ok, info = pcall(C_Spell.GetSpellCooldown, id)
		if not ok or (_G.issecretvalue and issecretvalue(info)) or type(info) ~= "table" then return nil end
		local start, duration, enabled, rate = Public(info.startTime), Public(info.duration),
			Public(info.isEnabled), Public(info.modRate)
		if _G.issecretvalue and issecretvalue(info.modRate) then return nil end
		if rate == nil then rate = 1 end
		if not Number(start, 1000000000) or not Number(duration, 31536000)
			or not Number(rate, 1000) or rate == 0 or (enabled ~= true and enabled ~= 1) then return nil end
		return start, duration, rate
	elseif type(_G.GetSpellCooldown) == "function" then
		local ok, start, duration, enabled, rate = pcall(GetSpellCooldown, id)
		if not ok then return nil end
		start, duration, enabled = Public(start), Public(duration), Public(enabled)
		if _G.issecretvalue and issecretvalue(rate) then return nil end
		if rate == nil then rate = 1 end
		if not Number(start, 1000000000) or not Number(duration, 31536000)
			or not Number(rate, 1000) or rate == 0 or (enabled ~= true and enabled ~= 1) then return nil end
		return start, duration, rate
	end
end

local function ChargesAPI(id)
	local fn = _G.C_Spell and C_Spell.GetSpellCharges
	if type(fn) ~= "function" and type(_G.GetSpellCharges) == "function" then
		local ok, current, maximum, start, duration, rate = pcall(GetSpellCharges, id)
		if not ok or (_G.issecretvalue and (issecretvalue(current) or issecretvalue(maximum)
			or issecretvalue(start) or issecretvalue(duration) or issecretvalue(rate))) then return nil end
		if current == nil then return false end
		if rate == nil then rate = 1 end
		if not Integer(current, 100, true) or not Integer(maximum, 100) or current > maximum
			or not Number(start, 1000000000) or not Number(duration, 31536000)
			or not Number(rate, 1000) or rate == 0 then return nil end
		return true, current, maximum, start, duration, rate
	end
	if type(fn) ~= "function" then return false end
	local ok, info = pcall(fn, id)
	if not ok or (_G.issecretvalue and issecretvalue(info)) then return nil end
	if info == nil then return false end
	if type(info) ~= "table" then return nil end
	local current, maximum = Public(info.currentCharges), Public(info.maxCharges)
	local start, duration, rate = Public(info.cooldownStartTime), Public(info.cooldownDuration), Public(info.chargeModRate)
	if _G.issecretvalue and issecretvalue(info.chargeModRate) then return nil end
	if rate == nil then rate = 1 end
	if not Integer(current, 100, true) or not Integer(maximum, 100) or current > maximum
		or not Number(start, 1000000000) or not Number(duration, 31536000)
		or not Number(rate, 1000) or rate == 0 then return nil end
	return true, current, maximum, start, duration, rate
end

function GroupStatus:CollectCooldowns()
	local now = Clock()
	if not now then self:Warn("clock", "Cooldown clock unavailable; group reports paused."); return {}, true end
	local gcdStart, gcdDuration = CooldownAPI(61304)
	local ids = {}
	for id in pairs(self.settings.groupWatch) do ids[id] = true end
	for id in pairs(self.casts) do ids[id] = true end
	for id in pairs(self.discovered) do ids[id] = true end
	local discoveredCount = 0
	for _ in pairs(self.discovered) do discoveredCount = discoveredCount + 1 end
	local rows, partial = {}, false
	for id in pairs(ids) do
		local start, duration, rate = CooldownAPI(id)
		local hasCharges, charges, maximum, chargeStart, chargeDuration, chargeRate = ChargesAPI(id)
		if start == nil or hasCharges == nil then
			partial = true
			self:Warn("cooldown", "Some cooldowns are protected or unavailable and cannot be shared.")
		else
			local isGCD = gcdStart and gcdDuration and gcdStart > 0
				and math.abs(start - gcdStart) < 0.05 and math.abs(duration - gcdDuration) < 0.05
			if not self.settings.groupWatch[id] and not self.discovered[id] then
				if not isGCD and discoveredCount < 60 and (duration >= 3 or (hasCharges and chargeDuration >= 3)) then
					self.discovered[id] = true
					discoveredCount = discoveredCount + 1
				elseif not isGCD and discoveredCount >= 60 and (duration >= 3 or (hasCharges and chargeDuration >= 3)) then
					self:Warn("discovery", "Automatic cooldown watch limit reached; use /healer watch for important spells.")
				end
				self.casts[id] = nil
			end
			if self.settings.groupWatch[id] or self.discovered[id] then
				local remaining = isGCD and 0 or math.max(0, (start + duration - now) / rate)
				if hasCharges and charges < maximum then
					remaining = math.max(0, (chargeStart + chargeDuration - now) / chargeRate)
				end
				remaining = math.min(31536000, math.ceil(remaining))
				rows[#rows + 1] = { id = id, remaining = remaining,
					charges = hasCharges and charges or nil, maximum = hasCharges and maximum or nil }
			end
		end
	end
	table.sort(rows, function(a, b) return a.id < b.id end)
	return rows, partial
end

function GroupStatus:CollectAuras()
	local api = _G.C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	local legacy = _G.UnitAura
	if type(api) ~= "function" and type(legacy) ~= "function" then
		self:Warn("aura", "Aura API unavailable; group effect reports are incomplete.")
		return {}, true
	end
	local now = Clock()
	if not now then self:Warn("clock", "Aura clock unavailable; group reports paused."); return {}, true end
	local rows, partial, seen = {}, false, {}
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for index = 1, 81 do
			local ok, aura, id, duration, expires, stacks
			if type(api) == "function" then
				ok, aura = pcall(api, "player", index, filter)
				if not ok or (_G.issecretvalue and issecretvalue(aura)) then partial = true; break end
				if aura == nil then break end
				if type(aura) ~= "table" then partial = true; break end
				id, duration, expires, stacks = Public(aura.spellId), Public(aura.duration),
					Public(aura.expirationTime), Public(aura.applications)
			else
				local name, icon, dispel, source, stealable, personal
				ok, name, icon, stacks, dispel, duration, expires, source, stealable, personal, id =
					pcall(legacy, "player", index, filter)
				if not ok or (_G.issecretvalue and issecretvalue(name)) then partial = true; break end
				if name == nil then break end
				id, duration, expires, stacks = Public(id), Public(duration), Public(expires), Public(stacks)
			end
			if index == 81 then partial = true; break end
			if not Integer(id, 1000000000) then
				partial = true
			else
				local remaining = "u"
				if Number(duration, 31536000) and duration == 0 then remaining = "p"
				elseif Number(duration, 31536000) and Number(expires, 1000000000) then
					remaining = tostring(math.min(31536000, math.ceil(math.max(0, expires - now))))
				else partial = true end
				local count = "u"
				if Integer(stacks, 10000, true) then count = tostring(stacks) else partial = true end
				local kind = filter == "HELPFUL" and "B" or "D"
				local key = kind .. ":" .. id
				if not seen[key] then
					seen[key] = true
					rows[#rows + 1] = { kind = kind, id = id, remaining = remaining, stacks = count }
				end
			end
		end
	end
	if partial then self:Warn("aura", "Some effects are protected, unavailable or exceed the report limit.") end
	table.sort(rows, function(a, b) if a.kind ~= b.kind then return a.kind < b.kind end return a.id < b.id end)
	return rows, partial
end

local function Encoded(kind, rows)
	local result = {}
	for _, row in ipairs(rows) do
		if kind == "A" then
			result[#result + 1] = table.concat({ row.kind, row.id, row.remaining, row.stacks }, ":")
		else
			result[#result + 1] = table.concat({ row.id, row.remaining, row.charges or "u", row.maximum or "u" }, ":")
		end
	end
	return result
end

function GroupStatus:QueueSnapshot(kind, rows, partial, collected)
	self.sequence = self.sequence + 1
	local token = tostring(self.generation) .. "-" .. tostring(self.sequence)
	local parts, buffer = {}, ""
	for _, value in ipairs(Encoded(kind, rows)) do
		local nextBuffer = buffer == "" and value or buffer .. "," .. value
		if #nextBuffer > 170 then parts[#parts + 1], buffer = buffer, value else buffer = nextBuffer end
	end
	parts[#parts + 1] = buffer
	if #parts > 32 then
		self:Warn("capacity", "Group report is too large and was not sent.")
		return false
	end
	local messages = {}
	for index, part in ipairs(parts) do
		messages[index] = { header = table.concat({ kind, token, index, #parts, partial and 1 or 0 }, "~"),
			payload = part, collected = collected }
	end
	self.pending[kind] = messages
	self:SendNext()
	return true
end

function GroupStatus:SendNext()
	if self.sending or self.sendBlocked or not self.settings.groupSharing then return end
	local channel = self:Context()
	if not channel then return end
	if not self.outgoing then
		if self.pending.H then self.outgoing, self.pending.H = self.pending.H, nil
		elseif self.pending.C and (not self.pending.A or self.lastKind ~= "C") then
			self.outgoing, self.pending.C, self.lastKind = self.pending.C, nil, "C"
		elseif self.pending.A then self.outgoing, self.pending.A, self.lastKind = self.pending.A, nil, "A"
		else return end
	end
	local message = self.outgoing[1]
	if type(message) == "table" then
		local now = Clock()
		if not now then
			self.outgoing = nil
			self:Warn("clock", "Group report clock unavailable; report was not sent.")
			return
		end
		local age = math.min(31536000, math.ceil(math.max(0, now - message.collected)))
		message = message.header .. "~" .. age .. "~" .. message.payload
	end
	local ok, result = pcall(C_ChatInfo.SendAddonMessage, self.prefix, message, channel)
	local protected = _G.issecretvalue and issecretvalue(result)
	local throttled = ok and not protected and (result == 3 or result == 8
		or (_G.Enum and Enum.SendAddonMessageResult and (result == Enum.SendAddonMessageResult.AddonMessageThrottle
			or result == Enum.SendAddonMessageResult.ChannelThrottle)))
	if throttled and (self.retries or 0) < 5 then
		self.retries, self.sending = (self.retries or 0) + 1, true
		local generation = self.generation
		C_Timer.After(2, function()
			if self.generation ~= generation then return end
			self.sending = false
			self:SendNext()
		end)
		return
	end
	if not ok or protected
		or (result ~= nil and result ~= true and result ~= 0) then
		self.outgoing, self.pending = nil, {}
		self:Warn("send", "Group status transfer failed (" .. (protected and "protected result" or tostring(result))
			.. "); retrying later.")
		self.sendBlocked = true
		local generation = self.generation
		C_Timer.After(30, function()
			if self.generation ~= generation then return end
			self.sendBlocked = false
			self:ScheduleUpdate(1)
		end)
		return
	end
	self.retries = nil
	self.warnings.send = nil
	table.remove(self.outgoing, 1)
	if #self.outgoing == 0 then self.outgoing = nil end
	self.sending = true
	local generation = self.generation
	C_Timer.After(0.5, function()
		if self.generation ~= generation then return end
		self.sending = false
		self:SendNext()
	end)
end

function GroupStatus:UpdateSnapshots()
	if not self.available or not self.settings.groupSharing or not self:Context() then return end
	local cooldowns, cooldownPartial = self:CollectCooldowns()
	local auras, auraPartial = self:CollectAuras()
	local now = Clock()
	if not now then return end
	self.lastSnapshot = now
	self.localReports = { C = { rows = cooldowns, partial = cooldownPartial, received = now },
		A = { rows = auras, partial = auraPartial, received = now } }
	self:QueueSnapshot("C", cooldowns, cooldownPartial, now)
	self:QueueSnapshot("A", auras, auraPartial, now)
	self:Refresh()
end

function GroupStatus:ScheduleUpdate(delay)
	if not self.available or not self.settings.groupSharing or self.updatePending then return end
	local pending = {}
	self.updatePending = pending
	local now = Clock()
	delay = delay or 1
	if now and self.lastSnapshot and now >= self.lastSnapshot then
		delay = math.max(delay, 5 - (now - self.lastSnapshot))
	end
	C_Timer.After(delay, function()
		if self.updatePending ~= pending then return end
		self.updatePending = nil
		self:UpdateSnapshots()
	end)
end

function GroupStatus:Periodic()
	if not self.available or not self.settings.groupSharing then return end
	local generation = self.generation
	C_Timer.After(30, function()
		if generation ~= self.generation or not self.settings.groupSharing then return end
		self:ScheduleUpdate(1)
		self:Periodic()
	end)
end

local function RosterSignature(channel, members, me)
	if not channel then return false end
	local names = {}
	for name in pairs(members) do names[#names + 1] = name end
	table.sort(names)
	return channel .. "~" .. me .. "~" .. table.concat(names, ",")
end

function GroupStatus:ResetGroup()
	self.generation = self.generation + 1
	self.rosterCache = nil
	self.peers, self.pending, self.outgoing, self.incoming = {}, {}, nil, {}
	self.sending, self.sendBlocked, self.retries, self.updatePending, self.localReports = false, false, nil, nil, nil
	self.lastSnapshot, self.lastKind = nil, nil
	self.rosterSignature = false
	if self.settings.groupSharing and self.available then
		local channel, members, me = self:Context()
		self.rosterSignature = RosterSignature(channel, members, me)
		if channel then
			self.pending.H = { "H" }
			self:SendNext()
			self:ScheduleUpdate(1)
		end
		self:Periodic()
	end
	self:Refresh()
end

function GroupStatus:SetEnabled(enabled)
	if enabled and not self.available then
		InfinityUtils:Warning("Group status sharing is unavailable on this client.", "Healer")
		return false
	end
	self.settings.groupSharing = not not enabled
	if not enabled then self.casts, self.discovered = {}, {} end
	self:ResetGroup()
	if self.settingsToggle then self.settingsToggle:SetChecked(self.settings.groupSharing) end
	if _G.InfinityHealerUI then InfinityHealerUI:Refresh() end
	return self.settings.groupSharing
end

function GroupStatus:RegisterSettings()
	if self.settingsCategory then return self.settingsCategory end
	local settings = _G.Settings
	local modern = settings and settings.RegisterCanvasLayoutCategory and settings.RegisterAddOnCategory
	if not modern and not _G.InterfaceOptions_AddCategory then
		self:Warn("settings", "Game settings unavailable; use /healer to configure group sharing.")
		return nil
	end
	local panel = CreateFrame("Frame", nil, UIParent)
	panel.name = "Infinity Healer"
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
	title:SetText(panel.name)
	local toggle = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	toggle:SetSize(20, 20)
	toggle:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -55)
	toggle:SetChecked(self.settings.groupSharing)
	toggle:SetScript("OnClick", function(button)
		self:SetEnabled(button:GetChecked())
		button:SetChecked(self.settings.groupSharing)
	end)
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	label:SetPoint("LEFT", toggle, "RIGHT", 5, 0)
	label:SetText("Share group cooldowns and effects")
	local details = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	details:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -8)
	details:SetWidth(480)
	details:SetJustifyH("LEFT")
	details:SetText("Shares your readable cooldown and effect IDs with the current group,\n"
		.. "including non-guild players. Applies to this character until disabled.\n"
		.. "Previously received reports may remain visible until stale.\n"
		.. "Protected values are omitted. /healer watch <spell ID> adds a cooldown.")
	local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	open:SetSize(170, 24)
	open:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -80)
	open:SetText("Open group reports")
	open:SetScript("OnClick", function() self:Toggle() end)
	self.settingsToggle = toggle
	panel:SetScript("OnShow", function() toggle:SetChecked(self.settings.groupSharing) end)
	local suite = _G.InfinitySettingsPanel
	if modern then
		if suite and suite.blizzardCategory and suite.blizzardCategory ~= suite.blizzardPanel
			and settings.RegisterCanvasLayoutSubcategory then
			self.settingsCategory = settings.RegisterCanvasLayoutSubcategory(suite.blizzardCategory, panel, panel.name)
		else
			self.settingsCategory = settings.RegisterCanvasLayoutCategory(panel, panel.name)
			settings.RegisterAddOnCategory(self.settingsCategory)
		end
	else
		if suite and suite.blizzardCategory == suite.blizzardPanel then panel.parent = "Infinity Suite" end
		_G.InterfaceOptions_AddCategory(panel)
		self.settingsCategory = panel
	end
	self.settingsPanel = panel
	return self.settingsCategory
end

function GroupStatus:RequestSync()
	if not self.available or not self.settings.groupSharing then
		InfinityUtils:Warning("Enable group status sharing before requesting reports.", "Healer")
		return false
	end
	if not self:Context() then
		InfinityUtils:Warning("Join a group or raid before requesting reports.", "Healer")
		return false
	end
	self:ResetGroup()
	print("Group status reports requested.")
	return true
end

function GroupStatus:Watch(id, enabled)
	if self.settingsInvalid then
		InfinityUtils:Warning("Cooldown watch settings are invalid and cannot be saved.", "Healer")
		return false
	end
	id = Public(id)
	if not Integer(id, 1000000000) then InfinityUtils:Warning("Enter a valid spell ID.", "Healer"); return false end
	local watches = self.settings.groupWatch
	local count = 0
	for _ in pairs(watches) do count = count + 1 end
	if enabled and not watches[id] and count >= 60 then
		InfinityUtils:Warning("The cooldown watch list is full.", "Healer")
		return false
	end
	watches[id] = enabled and true or nil
	if not enabled then self.casts[id], self.discovered[id] = nil, nil end
	self:ScheduleUpdate(1)
	return true
end

function GroupStatus:Initialize(settings)
	if self.initialized then return end
	local function InvalidSettings()
		self.settings = { groupSharing = false, groupWatch = {} }
		self.initialized, self.generation, self.available, self.settingsInvalid = true, 0, false, true
		self.pending, self.incoming, self.warnings = {}, {}, {}
		self:Warn("saved", "Invalid saved group status settings; sharing is unavailable.")
		self:RegisterSettings()
		return false
	end
	if _G.issecretvalue and (issecretvalue(settings.groupSharing) or issecretvalue(settings.groupWatch)) then
		return InvalidSettings()
	end
	local sharing, watches = settings.groupSharing, settings.groupWatch
	if (sharing ~= nil and type(sharing) ~= "boolean") or (watches ~= nil and type(watches) ~= "table") then
		return InvalidSettings()
	end
	local count = 0
	if watches then
		for id, enabled in pairs(watches) do
			if not Integer(id, 1000000000) or Public(enabled) ~= true then return InvalidSettings() end
			count = count + 1
		end
	end
	if count > 60 then return InvalidSettings() end
	if sharing == nil then settings.groupSharing = false end
	if watches == nil then settings.groupWatch = {} end
	self.settings, self.initialized, self.generation = settings, true, 0
	self.pending, self.incoming, self.warnings = {}, {}, {}
	self:RegisterSettings()
	if not (_G.C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix and C_ChatInfo.SendAddonMessage
		and _G.C_Timer and C_Timer.After and _G.GetTime) then
		self:Warn("api", "Group status sharing is unavailable on this client.")
		return
	end
	local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, self.prefix)
	local duplicate = _G.Enum and Enum.RegisterAddonMessagePrefixResult and Enum.RegisterAddonMessagePrefixResult.DuplicatePrefix or 1
	if not ok or (_G.issecretvalue and issecretvalue(result))
		or (result ~= nil and result ~= true and result ~= 0 and result ~= duplicate) then
		self:Warn("api", "Group status message prefix could not be registered.")
		return
	end
	self.available = true
	local frame = CreateFrame("Frame")
	for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "PLAYER_ENTERING_WORLD", "UNIT_AURA",
		"UNIT_SPELLCAST_SUCCEEDED", "SPELL_UPDATE_COOLDOWN", "CHAT_MSG_ADDON" }) do frame:RegisterEvent(event) end
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then self:OnMessage(...)
		elseif event == "PLAYER_ENTERING_WORLD" then self:ResetGroup()
		elseif event == "GROUP_ROSTER_UPDATE" then
			self.rosterCache = nil
			if self.settings.groupSharing then
				local channel, members, me = self:Context()
				if self.rosterSignature ~= RosterSignature(channel, members, me) then self:ResetGroup() end
			end
		elseif not self.settings.groupSharing then return
		elseif event == "UNIT_AURA" then
			if Public(...) == "player" then self:ScheduleUpdate(1) end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local unit, _, id = ...
			unit, id = Public(unit), Public(id)
			if unit == "player" and Integer(id, 1000000000) then
				local count, oldest, oldestSequence = 0, nil, nil
				for spell, sequence in pairs(self.casts) do
					count = count + 1
					if not oldestSequence or sequence < oldestSequence then oldest, oldestSequence = spell, sequence end
				end
				if not self.casts[id] and count >= 60 then self.casts[oldest] = nil end
				self.castSequence = (self.castSequence or 0) + 1
				self.casts[id] = self.castSequence
				self:ScheduleUpdate(1)
			end
		else self:ScheduleUpdate(1) end
	end)
	self.events = frame
	self:ResetGroup()
end

local function ParseRows(kind, parts, now)
	local rows, seen = {}, {}
	for _, entry in ipairs(parts) do
		local part = entry.payload
		local age = entry.age + math.max(0, now - entry.received)
		if part ~= "" then
			if part:sub(1, 1) == "," or part:sub(-1) == "," or part:find(",,", 1, true) then return nil end
			for item in part:gmatch("[^,]+") do
				local row, key
				if kind == "A" then
					local aura, id, remaining, stacks = item:match("^([BD]):(%d+):([%dpu]+):([%du]+)$")
					id = tonumber(id)
					if not aura or not Integer(id, 1000000000)
						or (remaining ~= "u" and remaining ~= "p" and not Integer(tonumber(remaining), 31536000, true))
						or (stacks ~= "u" and not Integer(tonumber(stacks), 10000, true)) then return nil end
					if remaining ~= "u" and remaining ~= "p" then
						remaining = tostring(math.ceil(math.max(0, tonumber(remaining) - age)))
					end
					row, key = { kind = aura, id = id, remaining = remaining, stacks = stacks }, aura .. ":" .. id
				else
					local id, remaining, charges, maximum = item:match("^(%d+):(%d+):([%du]+):([%du]+)$")
					id, remaining = tonumber(id), tonumber(remaining)
					if not Integer(id, 1000000000) or not Integer(remaining, 31536000, true) then return nil end
					remaining = math.ceil(math.max(0, remaining - age))
					if charges == "u" and maximum == "u" then charges, maximum = nil, nil
					else
						charges, maximum = tonumber(charges), tonumber(maximum)
						if not Integer(charges, 100, true) or not Integer(maximum, 100) or charges > maximum then return nil end
					end
					row, key = { id = id, remaining = remaining, charges = charges, maximum = maximum }, tostring(id)
				end
				if seen[key] or #rows >= 160 then return nil end
				seen[key] = true
				rows[#rows + 1] = row
			end
		end
	end
	return rows
end

function GroupStatus:OnMessage(prefix, message, channel, sender)
	prefix, message, channel, sender = Public(prefix), Public(message), Public(channel), Public(sender)
	if not self.available or not self.settings.groupSharing or prefix ~= self.prefix
		or type(message) ~= "string" or #message > 240 then return end
	local expected, members, me = self:Context()
	local key, now = SenderKey(sender), Clock()
	if not expected or channel ~= expected or not key or key == me or not members[key] or not now then return end
	if message == "H" then self:ScheduleUpdate(2); return end
	local kind, token, index, total, partial, age, payload =
		message:match("^([AC])~(%d+%-%d+)~(%d+)~(%d+)~([01])~(%d+)~(.*)$")
	index, total, age = tonumber(index), tonumber(total), tonumber(age)
	if not kind or #token > 32 or not Integer(index, 32) or not Integer(total, 32)
		or index > total or not Integer(age, 31536000, true) or #payload > 170 then return end
	self.incoming[key] = self.incoming[key] or {}
	local incoming = self.incoming[key][kind]
	if not incoming or incoming.token ~= token or now > incoming.deadline then
		incoming = { token = token, total = total, partial = partial == "1", parts = {}, count = 0, deadline = now + 60 }
		self.incoming[key][kind] = incoming
	end
	if incoming.total ~= total or incoming.partial ~= (partial == "1") then self.incoming[key][kind] = nil; return end
	if incoming.parts[index] and incoming.parts[index].payload ~= payload then self.incoming[key][kind] = nil; return end
	if not incoming.parts[index] then
		incoming.parts[index], incoming.count = { payload = payload, age = age, received = now }, incoming.count + 1
	end
	incoming.deadline = now + 60
	if incoming.count ~= total then return end
	local rows = ParseRows(kind, incoming.parts, now)
	self.incoming[key][kind] = nil
	if not rows then return end
	self.peers[key] = self.peers[key] or { name = sender }
	self.peers[key][kind] = { rows = rows, partial = incoming.partial, received = now }
	self:Refresh()
end

local function SpellLabel(id)
	if _G.C_Spell and type(C_Spell.GetSpellInfo) == "function" then
		local ok, info = pcall(C_Spell.GetSpellInfo, id)
		info = ok and Public(info)
		local name = type(info) == "table" and Public(info.name)
		if type(name) == "string" and name ~= "" and not name:find("[%z\1-\31|]") then return name .. " (#" .. id .. ")" end
	elseif type(_G.GetSpellInfo) == "function" then
		local ok, name = pcall(GetSpellInfo, id)
		name = ok and Public(name)
		if type(name) == "string" and name ~= "" and not name:find("[%z\1-\31|]") then return name .. " (#" .. id .. ")" end
	end
	return "Spell #" .. id
end

local function Duration(value, elapsed, stale)
	if stale then return "stale" end
	if value == "p" then return "permanent" end
	if value == "u" then return "duration unknown" end
	local remaining = tonumber(value)
	if not remaining then return "duration unknown" end
	return math.max(0, math.ceil(remaining - elapsed)) .. "s approx."
end

function GroupStatus:Refresh()
	if not self.window then return end
	if self.showWatches then return self:RefreshWatches() end
	local items, count = {}, 0
	local page = self.page or 1
	local first, last = (page - 1) * 35 + 1, page * 35
	local function Add(text)
		count = count + 1
		if count >= first and count <= last then items[#items + 1] = { text = text } end
	end
	local function AddRecord(kind, row, elapsed, stale)
		count = count + 1
		if count < first or count > last then return end
		local text
		if kind == "C" then
			text = "    " .. SpellLabel(row.id) .. ": " .. Duration(row.remaining, elapsed, stale)
			if row.maximum then text = text .. " | charges at report: " .. row.charges .. "/" .. row.maximum end
		else
			text = "    " .. (row.kind == "B" and "Buff: " or "Debuff: ") .. SpellLabel(row.id)
				.. " | " .. Duration(row.remaining, elapsed, stale)
			if row.stacks ~= "u" and row.stacks ~= "0" then text = text .. " | stacks: " .. row.stacks end
		end
		items[#items + 1] = { text = text }
	end
	local now = Clock()
	if not self.available then
		Add("Group status API unavailable.")
	elseif not self.settings.groupSharing then
		Add("Sharing is off. Enable it in the Healer window or game settings.")
	elseif not now then
		Add("Group status clock unavailable.")
	else
		local channel, members, me = self:Context()
		if not channel then Add("Join a group or raid to exchange reports.")
		else
			local groups = {}
			if self.localReports then groups[#groups + 1] = { name = me .. " (you)", data = self.localReports } end
			for key, peer in pairs(self.peers) do
				if members[key] then groups[#groups + 1] = { name = peer.name, data = peer } end
			end
			table.sort(groups, function(a, b) return a.name < b.name end)
			for _, group in ipairs(groups) do
				Add(group.name)
				for _, kind in ipairs({ "C", "A" }) do
					local report = group.data[kind]
					if report then
						local elapsed = math.max(0, now - report.received)
						local stale = elapsed > 90
						local title = kind == "C" and "Cooldowns" or "Effects"
						Add("  " .. title .. (report.partial and " (partial)" or "")
							.. " - " .. math.floor(elapsed) .. "s ago" .. (stale and " (stale)" or ""))
						for _, row in ipairs(report.rows) do
							AddRecord(kind, row, elapsed, stale)
						end
					end
				end
			end
			if count == 0 then Add("Waiting for opted-in group members.") end
		end
	end
	local pages = math.max(1, math.ceil(count / 35))
	if page > pages then self.page = pages; return self:Refresh() end
	self.window.status:SetText("Page " .. page .. "/" .. pages .. " | Approximate reports; protected data omitted.")
	self.window:SetItems(items)
end

function GroupStatus:RefreshWatches()
	local ids, items = {}, {}
	for id in pairs(self.settings.groupWatch) do ids[#ids + 1] = id end
	table.sort(ids)
	local page = math.min(self.page or 1, math.max(1, math.ceil(#ids / 35)))
	self.page = page
	for index = (page - 1) * 35 + 1, math.min(page * 35, #ids) do
		local id = ids[index]
		items[#items + 1] = {
			text = SpellLabel(id) .. " - click to stop watching",
			onClick = function()
				if self:Watch(id, false) then self:RefreshWatches() end
			end,
		}
	end
	if #items == 0 then items[1] = { text = "No explicitly watched spells." } end
	self.window.status:SetText("Watched IDs | Page " .. page .. "/" .. math.max(1, math.ceil(#ids / 35))
		.. " | Click a spell to remove it.")
	self.window:SetItems(items)
end

function GroupStatus:Toggle()
	if not _G.InfinityUIFramework then
		InfinityUtils:Warning("Group status window unavailable.", "Healer")
		return
	end
	if not self.window then
		self.window = InfinityUIFramework:CreateListWindow("InfinityGroupStatusWindow", "Group Cooldowns and Effects", 720, 550)
		local previous = InfinityUIFramework:CreateButton(self.window, "Previous", 80, 20, function()
			self.page = math.max(1, (self.page or 1) - 1)
			if self.showWatches then self:RefreshWatches() else self:Refresh() end
		end)
		previous:SetPoint("TOPLEFT", self.window, "TOPLEFT", 20, -38)
		local nextPage = InfinityUIFramework:CreateButton(self.window, "Next", 80, 20, function()
			self.page = (self.page or 1) + 1
			if self.showWatches then self:RefreshWatches() else self:Refresh() end
		end)
		nextPage:SetPoint("LEFT", previous, "RIGHT", 8, 0)
		self.watchInput = CreateFrame("EditBox", nil, self.window, "InputBoxTemplate")
		self.watchInput:SetSize(90, 20)
		self.watchInput:SetPoint("LEFT", nextPage, "RIGHT", 16, 0)
		self.watchInput:SetAutoFocus(false)
		self.watchInput:SetMaxLetters(10)
		local function ChangeWatch(enabled)
			local value = Public(self.watchInput:GetText())
			local id = type(value) == "string" and value:match("^%s*(%d+)%s*$")
			if self:Watch(id and tonumber(id), enabled) then
				if self.showWatches then self:RefreshWatches() else self:Refresh() end
				print((enabled and "Watching" or "Unwatched") .. " spell " .. id)
			end
		end
		local watch = InfinityUIFramework:CreateButton(self.window, "Watch ID", 80, 20, function() ChangeWatch(true) end)
		watch:SetPoint("LEFT", self.watchInput, "RIGHT", 8, 0)
		local unwatch = InfinityUIFramework:CreateButton(self.window, "Unwatch", 80, 20, function() ChangeWatch(false) end)
		unwatch:SetPoint("LEFT", watch, "RIGHT", 5, 0)
		local sync = InfinityUIFramework:CreateButton(self.window, "Sync", 65, 20, function() self:RequestSync() end)
		sync:SetPoint("LEFT", unwatch, "RIGHT", 5, 0)
		local view = InfinityUIFramework:CreateButton(self.window, "Watch list", 85, 20, function()
			self.showWatches = not self.showWatches
			self.page = 1
			if self.showWatches then self:RefreshWatches() else self:Refresh() end
		end)
		view:SetPoint("LEFT", sync, "RIGHT", 5, 0)
	end
	if self.window:IsShown() then self.window:Hide(); return end
	if self.showWatches then self:RefreshWatches() else self:Refresh() end
	self.window:Show()
	if not self.viewTicker and _G.C_Timer and C_Timer.After then
		local function Update()
			if not self.window or not self.window:IsShown() then self.viewTicker = nil; return end
			if self.showWatches then self:RefreshWatches() else self:Refresh() end
			C_Timer.After(1, Update)
		end
		self.viewTicker = true
		C_Timer.After(1, Update)
	end
end

return GroupStatus
