local ClickCast = {}
_G.InfinityClickCast = ClickCast

local attributes = {
	right = { "type2", "spell2" },
	["shift-right"] = { "shift-type2", "shift-spell2" },
	["ctrl-right"] = { "ctrl-type2", "ctrl-spell2" },
	["alt-right"] = { "alt-type2", "alt-spell2" },
}

function ClickCast:Initialize(settings)
	if type(settings) ~= "table" then error("Healer settings unavailable") end
	if _G.issecretvalue and _G.issecretvalue(settings.bindings) then error("Protected healer click bindings") end
	if settings.bindings == nil then settings.bindings = {} end
	if type(settings.bindings) ~= "table" then error("Invalid healer click bindings") end
	for key, spell in pairs(settings.bindings) do
		if (_G.issecretvalue and _G.issecretvalue(spell)) or not attributes[key]
			or type(spell) ~= "number" or spell ~= spell or spell <= 0
			or spell >= math.huge or spell ~= math.floor(spell) then error("Invalid saved healer click binding") end
	end
	self.bindings = settings.bindings
end

function ClickCast:Apply(frame)
	if InCombatLockdown and InCombatLockdown() then return false end
	frame:SetAttribute("type1", "target")
	for key, names in pairs(attributes) do
		local spell = self.bindings[key]
		frame:SetAttribute(names[1], spell and "spell" or nil)
		frame:SetAttribute(names[2], spell)
	end
	local onDown = _G.GetCVarBool and _G.GetCVarBool("ActionButtonUseKeyDown")
	if _G.issecretvalue and _G.issecretvalue(onDown) then onDown = false end
	onDown = onDown == true or onDown == 1
	frame:SetAttribute("useOnKeyDown", onDown)
	frame:RegisterForClicks(onDown and "AnyDown" or "AnyUp")
	return true
end

function ClickCast:SetBinding(key, spellID)
	if _G.issecretvalue and (_G.issecretvalue(key) or _G.issecretvalue(spellID)) then
		InfinityUtils:Warning("Protected click binding cannot be saved.", "Healer")
		return false
	end
	if type(key) ~= "string" or not attributes[key] then
		InfinityUtils:Warning("Use right, shift-right, ctrl-right, or alt-right.", "Healer")
		return false
	end
	if spellID ~= nil and (type(spellID) ~= "number" or spellID ~= spellID or spellID <= 0
		or spellID >= math.huge or spellID ~= math.floor(spellID)) then
		InfinityUtils:Warning("Spell ID must be a positive integer or clear.", "Healer")
		return false
	end
	self.bindings[key] = spellID
	InfinityHealer:RefreshRaidFrames()
	if InCombatLockdown and InCombatLockdown() then
		print("Click binding saved; secure frames update after combat.")
	else
		print("Click binding updated: " .. key .. " = " .. (spellID or "clear"))
	end
	return true
end

function ClickCast:GetAllBindings()
	return self.bindings
end

return ClickCast
