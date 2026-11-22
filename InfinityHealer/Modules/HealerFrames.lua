local Healer = { frames = {} }
_G.InfinityHealer = Healer

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

function Healer:Initialize()
	if self.eventFrame then return true end
	local guid = _G.UnitGUID and Public(UnitGUID("player"))
	if type(guid) ~= "string" or guid == "" then return false end
	local db = InfinityCore:GetDatabase("InfinityHealer")
	if type(db) ~= "table" then error("Healer database unavailable") end
	if db.characters == nil then db.characters = {} end
	if type(db.characters) ~= "table" then error("Invalid healer character settings") end
	if db.characters[guid] == nil then db.characters[guid] = {} end
	if type(db.characters[guid]) ~= "table" then error("Invalid healer character configuration") end
	self.settings = db.characters[guid]
	if _G.issecretvalue and (_G.issecretvalue(self.settings.visible) or _G.issecretvalue(self.settings.scale)) then
		error("Protected healer display settings")
	end
	if self.settings.visible == nil then self.settings.visible = true end
	if self.settings.scale == nil then self.settings.scale = 1 end
	if type(self.settings.visible) ~= "boolean" or type(self.settings.scale) ~= "number"
		or self.settings.scale ~= self.settings.scale or self.settings.scale < 0.5 or self.settings.scale > 2 then
		error("Invalid healer display settings")
	end
	InfinityClickCast:Initialize(self.settings)
	local events = CreateFrame("Frame")
	events:RegisterEvent("GROUP_ROSTER_UPDATE")
	events:RegisterEvent("PLAYER_ENTERING_WORLD")
	events:RegisterEvent("PLAYER_REGEN_ENABLED")
	events:RegisterEvent("UNIT_HEALTH")
	events:RegisterEvent("UNIT_MAXHEALTH")
	events:RegisterEvent("UNIT_NAME_UPDATE")
	events:RegisterEvent("CVAR_UPDATE")
	events:SetScript("OnEvent", function(_, event, ...)
		if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_NAME_UPDATE" then
			local unit = Public(...)
			if type(unit) == "string" then self:UpdateUnit(unit) end
		elseif event == "CVAR_UPDATE" then
			local name = Public(...)
			if type(name) == "string" and name:lower() == "actionbuttonusekeydown" then self:RefreshRaidFrames() end
		elseif event ~= "PLAYER_REGEN_ENABLED" or self.pending then
			self:RefreshRaidFrames(event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD")
		end
	end)
	self.eventFrame = events
	self:RefreshRaidFrames()
	return true
end

function Healer:CreateUnitFrame(unit)
	local template = BackdropTemplateMixin and "SecureUnitButtonTemplate,BackdropTemplate" or "SecureUnitButtonTemplate"
	local frame = CreateFrame("Button", "InfinityHealer_" .. unit, UIParent, template)
	frame:SetSize(125, 38)
	frame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
	frame:SetAttribute("unit", unit)
	frame:SetAttribute("checkselfcast", false)
	frame:SetAttribute("checkfocuscast", false)
	frame:SetAttribute("checkmouseovercast", false)
	frame:SetAttribute("toggleForVehicle", true)
	frame.nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.nameText:SetPoint("TOPLEFT", 5, -4)
	frame.nameText:SetWidth(115)
	frame.nameText:SetJustifyH("LEFT")
	frame.healthBar = CreateFrame("StatusBar", nil, frame)
	frame.healthBar:SetPoint("BOTTOMLEFT", 4, 4)
	frame.healthBar:SetSize(117, 12)
	frame.healthBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	frame.healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 1)
	frame.healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	frame.healthText:SetPoint("CENTER", frame.healthBar, "CENTER")
	self.frames[unit] = frame
	return frame
end

function Healer:UpdateUnit(unit)
	local frame = self.frames[unit]
	if not frame or self.rosterPending then return end
	local name = _G.UnitName and UnitName(unit)
	if _G.issecretvalue and _G.issecretvalue(name) then
		frame.nameText:SetText(name)
	else
		frame.nameText:SetText(type(name) == "string" and name or unit)
	end
	local health = _G.UnitHealth and UnitHealth(unit)
	local maximum = _G.UnitHealthMax and UnitHealthMax(unit)
	local healthSecret = _G.issecretvalue and _G.issecretvalue(health)
	local maximumSecret = _G.issecretvalue and _G.issecretvalue(maximum)
	if healthSecret or maximumSecret then
		local healthOK = healthSecret or (type(health) == "number" and health == health and health >= 0 and health < math.huge)
		local maxOK = maximumSecret or (type(maximum) == "number" and maximum == maximum and maximum > 0 and maximum < math.huge)
		if healthOK and maxOK then
			frame.healthBar:SetMinMaxValues(0, maximum)
			frame.healthBar:SetValue(health)
		else
			frame.healthBar:SetMinMaxValues(0, 1)
			frame.healthBar:SetValue(0)
		end
		frame.healthText:SetText("?")
		return
	end
	if type(health) ~= "number" or type(maximum) ~= "number" or health ~= health or maximum ~= maximum
		or health < 0 or maximum <= 0 or health >= math.huge or maximum >= math.huge then
		frame.healthBar:SetMinMaxValues(0, 1)
		frame.healthBar:SetValue(0)
		frame.healthText:SetText("?")
		return
	end
	frame.healthBar:SetMinMaxValues(0, maximum)
	frame.healthBar:SetValue(health)
	frame.healthText:SetText(string.format("%.0f%%", math.min(100, health * 100 / maximum)))
end

function Healer:RefreshRaidFrames(rosterChanged)
	if InCombatLockdown and InCombatLockdown() then
		self.pending = true
		if rosterChanged then
			self.rosterPending = true
			for _, frame in pairs(self.frames) do
				frame.nameText:SetText("Roster changed")
				frame.healthText:SetText("")
				frame.healthBar:SetMinMaxValues(0, 1)
				frame.healthBar:SetValue(0)
			end
		end
		return false
	end
	local count = _G.GetNumGroupMembers and GetNumGroupMembers()
	local raid = _G.IsInRaid and IsInRaid()
	if _G.issecretvalue and (_G.issecretvalue(count) or _G.issecretvalue(raid)) then
		self.pending, self.rosterPending = true, true
		for _, frame in pairs(self.frames) do frame:Hide() end
		InfinityUtils:Warning("Group roster is protected; healer frames were hidden.", "Healer")
		return false
	end
	if type(count) ~= "number" or count < 0 or count > 40 or count ~= math.floor(count)
		or (raid ~= nil and raid ~= false and raid ~= true and raid ~= 1)
		or ((raid == nil or raid == false) and count > 5) then
		self.pending, self.rosterPending = true, true
		for _, frame in pairs(self.frames) do frame:Hide() end
		InfinityUtils:Warning("Group roster unavailable; healer frames were hidden.", "Healer")
		return false
	end
	local units = {}
	if self.settings.visible and count > 0 then
		if raid == true or raid == 1 then
			for i = 1, count do units[#units + 1] = "raid" .. i end
		else
			units[1] = "player"
			for i = 1, math.min(4, count - 1) do units[#units + 1] = "party" .. i end
		end
	end
	self.rosterPending = false
	for _, frame in pairs(self.frames) do frame:Hide() end
	for index, unit in ipairs(units) do
		local frame = self.frames[unit] or self:CreateUnitFrame(unit)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 10 + math.floor((index - 1) / 5) * 130,
			-100 - ((index - 1) % 5) * 42)
		frame:SetScale(self.settings.scale)
		InfinityClickCast:Apply(frame)
		self:UpdateUnit(unit)
		frame:Show()
	end
	self.pending = false
	return true
end

function Healer:ToggleFrames()
	self.settings.visible = not self.settings.visible
	if not self:RefreshRaidFrames() and InCombatLockdown and InCombatLockdown() then
		print("Frame visibility saved; applies after combat.")
	end
	return self.settings.visible
end

function Healer:SetFrameScale(scale)
	if type(scale) ~= "number" or scale ~= scale or scale < 0.5 or scale > 2 then
		InfinityUtils:Warning("Frame scale must be between 0.5 and 2.", "Healer")
		return false
	end
	self.settings.scale = scale
	if not self:RefreshRaidFrames() and InCombatLockdown and InCombatLockdown() then
		print("Frame scale saved; applies after combat.")
	end
	return true
end

return Healer
