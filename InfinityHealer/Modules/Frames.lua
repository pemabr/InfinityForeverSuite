-- Infinity Healer - Raid Frame Manager
-- Clickable healing interface for healers

InfinityHealerFrames = {
	frames = {},
	settings = {
		scale = 1.0,
		alpha = 0.9,
		maxHealth = true,
		showMana = true,
		showDebuffs = true,
	},
	version = 1,
}

function InfinityHealerFrames:Initialize()
	InfinityDataManager:RegisterSource("healer_frames", function(data) end)
	InfinityUtils:Info("Healer Frames initialized", "Healer")
end

function InfinityHealerFrames:CreateUnitFrame(unit, name)
	if not unit or not name then
		return nil
	end
	
	local frame = CreateFrame("Button", "InfinityHealerFrame_" .. unit, UIParent)
	frame:SetSize(100, 50)
	frame:EnableMouse(true)
	frame.unit = unit
	frame.name = name
	
	-- Background
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 }
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
	
	-- Name
	local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	nameText:SetText(name)
	nameText:SetFontObject(GameFontNormal)
	frame.nameText = nameText
	
	-- Health bar
	local healthBar = CreateFrame("StatusBar", nil, frame)
	healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -15)
	healthBar:SetSize(98, 15)
	healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	healthBar:SetStatusBarColor(0.3, 0.9, 0.3, 1)
	healthBar:SetValue(100)
	healthBar:SetMaxValue(100)
	frame.healthBar = healthBar
	
	-- Health text
	local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	healthText:SetPoint("CENTER", healthBar, "CENTER", 0, 0)
	healthText:SetFontObject(GameFontNormal)
	healthText:SetFont("Fonts/FRIZQT__.TTF", 8, "")
	healthText:SetText("100%")
	frame.healthText = healthText
	
	-- Mana bar (if applicable)
	local manaBar = CreateFrame("StatusBar", nil, frame)
	manaBar:SetPoint("TOPLEFT", healthBar, "BOTTOMLEFT", 0, -1)
	manaBar:SetSize(98, 8)
	manaBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	manaBar:SetStatusBarColor(0.0, 0.3, 1.0, 1)
	manaBar:SetValue(100)
	manaBar:SetMaxValue(100)
	frame.manaBar = manaBar
	
	-- Click binding
	frame:SetScript("OnClick", function(self, button)
		InfinityHealerFrames:OnFrameClick(self, button)
	end)
	
	-- Mouseover
	frame:SetScript("OnEnter", function(self)
		if self.unit then
			UnitFrame_OnEnter(self)
		end
	end)
	
	frame:SetScript("OnLeave", function(self)
		GameTooltip:Hide()
	end)
	
	self.frames[unit] = frame
	return frame
end

function InfinityHealerFrames:UpdateFrame(unit)
	local frame = self.frames[unit]
	if not frame then
		return
	end
	
	-- Update health
	local health, maxHealth = UnitHealth(unit), UnitHealthMax(unit)
	local healthPercent = (health / maxHealth) * 100
	frame.healthBar:SetValue(healthPercent)
	frame.healthText:SetText(string.format("%.0f%%", healthPercent))
	
	-- Update color based on health
	if healthPercent > 50 then
		frame.healthBar:SetStatusBarColor(0.3, 0.9, 0.3, 1)
	elseif healthPercent > 25 then
		frame.healthBar:SetStatusBarColor(1, 1, 0, 1)
	else
		frame.healthBar:SetStatusBarColor(1, 0.3, 0.3, 1)
	end
	
	-- Update mana if applicable
	if UnitPowerType(unit) == 0 then -- Mana
		local mana, maxMana = UnitMana(unit), UnitManaMax(unit)
		local manaPercent = (mana / maxMana) * 100
		frame.manaBar:SetValue(manaPercent)
	end
	
	-- Update status (online/offline)
	if not UnitIsConnected(unit) then
		frame:SetAlpha(0.5)
	else
		frame:SetAlpha(1)
	end
end

function InfinityHealerFrames:UpdateAllFrames()
	for unit, frame in pairs(self.frames) do
		self:UpdateFrame(unit)
	end
end

function InfinityHealerFrames:OnFrameClick(frame, button)
	if not frame.unit then
		return
	end
	
	-- Get spell keybind
	local spellInfo = InfinityHealerSpells:GetSpellForButton(button)
	if not spellInfo then
		return
	end
	
	-- Cast spell on target
	local name, rank, icon, castTime, minRange, maxRange = GetSpellInfo(spellInfo.spellID)
	
	if name then
		InfinityUtils:Info("Casting " .. name .. " on " .. frame.name, "Healer")
		-- In actual WoW, would cast the spell
		InfinityMessaging:Publish("healer_spell_cast", {
			spell = name,
			target = frame.name,
			unit = frame.unit,
		})
	end
end

function InfinityHealerFrames:ShowRaidFrames()
	-- Get current party/raid members
	local maxPlayers = IsInRaid() and GetNumGroupMembers() or GetNumSubgroupMembers()
	
	for i = 1, maxPlayers do
		local unit = IsInRaid() and ("raid" .. i) or ("party" .. i)
		if UnitExists(unit) then
			local name = UnitName(unit)
			local frame = self:CreateUnitFrame(unit, name)
			if frame then
				-- Position frames in a grid
				local row = math.floor((i - 1) / 5)
				local col = (i - 1) % 5
				frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50 + (col * 110), -100 - (row * 70))
				frame:Show()
			end
		end
	end
	
	-- Also add player frame
	local playerFrame = self:CreateUnitFrame("player", UnitName("player"))
	if playerFrame then
		playerFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 50, 50)
		playerFrame:Show()
	end
	
	InfinityUtils:Info("Raid frames shown", "Healer")
end

function InfinityHealerFrames:HideRaidFrames()
	for unit, frame in pairs(self.frames) do
		frame:Hide()
	end
	InfinityUtils:Info("Raid frames hidden", "Healer")
end

function InfinityHealerFrames:ToggleRaidFrames()
	if self.frames[1] and self.frames[1]:IsShown() then
		self:HideRaidFrames()
	else
		self:ShowRaidFrames()
	end
end

return InfinityHealerFrames
