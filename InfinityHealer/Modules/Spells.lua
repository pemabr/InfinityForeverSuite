-- Infinity Healer - Spell Management
-- Manages healing spells and keybinds

InfinityHealerSpells = {
	spells = {},
	keybinds = {},
	version = 1,
}

function InfinityHealerSpells:Initialize()
	self:RegisterDefaultSpells()
	InfinityUtils:Info("Spell manager initialized", "Healer")
end

function InfinityHealerSpells:RegisterDefaultSpells()
	-- Priest
	self:RegisterSpell(2060, "Heal", 1, 1) -- Button 1 for Priest
	self:RegisterSpell(596, "Power Word: Shield", 1, 2)
	self:RegisterSpell(32379, "Shadow Word: Pain", 1, 3)
	
	-- Druid
	self:RegisterSpell(774, "Rejuvenation", 2, 1) -- Button 1 for Druid
	self:RegisterSpell(1058, "Regrowth", 2, 2)
	self:RegisterSpell(339, "Entangling Roots", 2, 3)
	
	-- Paladin
	self:RegisterSpell(19750, "Flash of Light", 3, 1) -- Button 1 for Paladin
	self:RegisterSpell(635, "Holy Light", 3, 2)
	self:RegisterSpell(1038, "Holy Wrath", 3, 3)
	
	-- Shaman
	self:RegisterSpell(331, "Healing Wave", 4, 1) -- Button 1 for Shaman
	self:RegisterSpell(547, "Lesser Healing Wave", 4, 2)
	self:RegisterSpell(686, "Shadow Bolt", 4, 3)
	
	-- Monk (if present)
	self:RegisterSpell(115072, "Enveloping Mist", 5, 1) -- Button 1 for Monk
	self:RegisterSpell(116694, "Jab", 5, 2)
	
	InfinityUtils:Info("Default spells registered", "Healer")
end

function InfinityHealerSpells:RegisterSpell(spellID, spellName, classID, buttonNum)
	if not self.spells[classID] then
		self.spells[classID] = {}
	end
	
	self.spells[classID][buttonNum] = {
		spellID = spellID,
		name = spellName,
		class = classID,
		button = buttonNum,
	}
	
	return true
end

function InfinityHealerSpells:GetSpellForButton(buttonNum)
	-- Get player class
	local _, classEnglish = UnitClass("player")
	local classID = select(3, UnitClass("player"))
	
	if self.spells[classID] and self.spells[classID][buttonNum] then
		return self.spells[classID][buttonNum]
	end
	
	return nil
end

function InfinityHealerSpells:GetAllSpells()
	return self.spells
end

function InfinityHealerSpells:SetButtonSpell(classID, buttonNum, spellID, spellName)
	if not self.spells[classID] then
		self.spells[classID] = {}
	end
	
	self.spells[classID][buttonNum] = {
		spellID = spellID,
		name = spellName,
		class = classID,
		button = buttonNum,
	}
	
	InfinityMessaging:Publish("healer_spell_updated", {
		class = classID,
		button = buttonNum,
		spell = spellName,
	})
	
	return true
end

function InfinityHealerSpells:CastSpellOnTarget(spellID, targetUnit)
	if not spellID or not targetUnit then
		return false
	end
	
	local spellName
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellID)
		spellName = info and info.name
	elseif GetSpellInfo then
		spellName = GetSpellInfo(spellID)
	end
	if not spellName then
		InfinityUtils:Warning("Spell not found: " .. tostring(spellID), "Healer")
		return false
	end
	
	-- Publish event for spell cast
	InfinityMessaging:Publish("healer_spell_cast", {
		spellID = spellID,
		spell = spellName,
		target = UnitName(targetUnit),
	})
	
	InfinityUtils:Info("Cast " .. spellName .. " on " .. UnitName(targetUnit), "Healer")
	return true
end

return InfinityHealerSpells
