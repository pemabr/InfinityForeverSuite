-- InfinityHealer - Main Module
-- Comprehensive raid healing UI with frames, click-casting, and predictions

local InfinityHealer = {}
_G.InfinityHealer = InfinityHealer

-- Configuration
InfinityHealer.config = {
	enableRaidFrames = true,
	enableClickCast = true,
	enableHealingPrediction = true,
	enableHoTTracking = true,
	maxFrames = 40,
	frameUpdateInterval = 0.1, -- seconds
	healthUpdateInterval = 1, -- Hz
	healthFormat = "PERCENT", -- "PERCENT", "ACTUAL", or "BOTH"
}

-- Core state
InfinityHealer.frames = {} -- {unitToken = frame}
InfinityHealer.activeHeals = {} -- {unitToken = {spell, amount, duration}}
InfinityHealer.hotData = {} -- {unitToken = {buffName = {duration, caster}}}
InfinityHealer.playerSpells = {} -- {spellName = {spellId, cooldown, range}}
InfinityHealer.settings = {
	layoutMode = "group", -- "group", "raid", or "party"
	frameSize = {width = 100, height = 40},
	frameSpacing = 2,
	enableMouseover = true,
	enableClickcast = true,
	enablePrediction = true,
}

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize healing UI system
function InfinityHealer:Initialize()
	InfinityUtils:Info("InfinityHealer initializing...", "Healer")
	
	-- Load saved settings
	self.settings = InfinityStorageManager:GetFeatureSettings("healer") or self.settings
	
	-- Register for group updates
	self:RegisterEvents()
	
	-- Build initial frames if in a group
	if GetNumGroupMembers() > 0 then
		self:RefreshRaidFrames()
	end
	
	InfinityUtils:Info("InfinityHealer initialized", "Healer")
end

--- Register for WoW events
function InfinityHealer:RegisterEvents()
	local frame = CreateFrame("Frame")
	
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("UNIT_HEALTH")
	frame:RegisterEvent("UNIT_HEALTH_FREQUENT")
	frame:RegisterEvent("UNIT_AURA")
	frame:RegisterEvent("SPELL_CAST_SUCCESS")
	frame:RegisterEvent("SPELL_CAST_FAILED")
	frame:RegisterEvent("UNIT_SPELLCAST_START")
	frame:RegisterEvent("UNIT_SPELLCAST_STOP")
	frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
	frame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	frame:RegisterEvent("RAID_ROSTER_UPDATE")
	frame:RegisterEvent("ARENA_OPPONENT_UPDATE")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		InfinityHealer:OnEvent(event, ...)
	end)
end

--- Handle WoW events
function InfinityHealer:OnEvent(event, ...)
	if event == "GROUP_ROSTER_UPDATE" or event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
		self:RefreshRaidFrames()
	elseif event == "UNIT_HEALTH" or event == "UNIT_HEALTH_FREQUENT" then
		local unit = ...
		self:UpdateUnitHealth(unit)
	elseif event == "UNIT_AURA" then
		local unit = ...
		self:UpdateUnitAuras(unit)
	elseif event == "SPELL_CAST_SUCCESS" then
		local castGUID, spellId = ...
		self:OnSpellCast(spellId)
	end
end

-- ============================================================================
-- RAID FRAME MANAGEMENT
-- ============================================================================

--- Create or update raid frames for all group members
function InfinityHealer:RefreshRaidFrames()
	local groupSize = GetNumGroupMembers()
	
	if groupSize == 0 then
		self:ClearRaidFrames()
		return
	end
	
	-- Determine frame configuration based on group size
	if groupSize <= 5 then
		self.settings.layoutMode = "party"
	elseif groupSize <= 10 then
		self.settings.layoutMode = "smallRaid"
	else
		self.settings.layoutMode = "raid"
	end
	
	-- Create frames for each group member
	for i = 1, groupSize do
		local unitToken = self:GetUnitToken(i, groupSize)
		if unitToken and not self.frames[unitToken] then
			self:CreateUnitFrame(unitToken)
		end
	end
	
	-- Layout frames
	self:LayoutFrames()
	
	InfinityUtils:Debug("Raid frames refreshed. Mode: " .. self.settings.layoutMode .. ", Members: " .. groupSize, "Healer")
end

--- Get unit token for a group member (raid1, raid2, party1, etc.)
function InfinityHealer:GetUnitToken(index, groupSize)
	if groupSize <= 5 then
		if index == 1 then
			return "player"
		else
			return "party" .. (index - 1)
		end
	else
		return "raid" .. index
	end
end

--- Create a unit frame for a player
function InfinityHealer:CreateUnitFrame(unitToken)
	if not UnitExists(unitToken) then
		return nil
	end
	
	local frameName = "InfinityHealer_" .. unitToken
	local frame = CreateFrame("Button", frameName, UIParent, "SecureActionButtonTemplate")
	
	-- Frame styling
	frame:SetSize(self.settings.frameSize.width, self.settings.frameSize.height)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = {left = 2, right = 2, top = 2, bottom = 2}
	})
	frame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
	
	-- Name text
	local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	nameText:SetText(UnitName(unitToken) or "Unknown")
	nameText:SetTextColor(1, 1, 1, 1)
	nameText:SetWidth(self.settings.frameSize.width - 4)
	nameText:SetFontObject("GameFontNormalSmall")
	nameText:SetJustifyH("LEFT")
	
	-- Health bar
	local healthBar = CreateFrame("StatusBar", nil, frame)
	healthBar:SetSize(self.settings.frameSize.width - 4, 12)
	healthBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -15)
	healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Green
	
	-- Health text
	local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	healthText:SetPoint("CENTER", healthBar, "CENTER")
	healthText:SetText("100%")
	healthText:SetFontObject("GameFontNormalSmall")
	healthText:SetJustifyH("CENTER")
	
	-- Store references
	frame.unitToken = unitToken
	frame.nameText = nameText
	frame.healthBar = healthBar
	frame.healthText = healthText
	frame.auras = {} -- Will store aura frames
	
	-- Enable mouseove highlighting
	if self.settings.enableMouseover then
		frame:SetScript("OnEnter", function(f)
			InfinityHealer:HighlightFrame(f)
		end)
		frame:SetScript("OnLeave", function(f)
			InfinityHealer:UnhighlightFrame(f)
		end)
	end
	
	-- Enable click-casting if enabled
	if self.settings.enableClickcast then
		self:SetupClickCasting(frame)
	end
	
	-- Update initial data
	self:UpdateUnitHealth(unitToken)
	self:UpdateUnitAuras(unitToken)
	
	self.frames[unitToken] = frame
	
	return frame
end

--- Set up click-casting for a frame
function InfinityHealer:SetupClickCasting(frame)
	-- Make frame secure for action buttons
	frame:SetAttribute("type", "spell")
	frame:SetAttribute("spell", "") -- Will be set when clicked
	
	-- Right-click to cast spell 1
	frame:SetAttribute("*type1", "spell")
	frame:SetAttribute("*spell1", "Heal") -- Default spell
	
	-- Shift+click for spell 2
	frame:SetAttribute("shift-type1", "spell")
	frame:SetAttribute("shift-spell1", "Renew")
	
	-- Ctrl+click for spell 3
	frame:SetAttribute("ctrl-type1", "spell")
	frame:SetAttribute("ctrl-spell1", "Power Word: Shield")
	
	-- Alt+click for spell 4
	frame:SetAttribute("alt-type1", "spell")
	frame:SetAttribute("alt-spell1", "Prayer of Mending")
	
	frame:SetScript("OnClick", function(f, button)
		if button == "RightButton" then
			InfinityHealer:OnFrameClick(f, "heal")
		end
	end)
end

--- Layout frames based on current mode
function InfinityHealer:LayoutFrames()
	local mode = self.settings.layoutMode
	local xOffset = 10
	local yOffset = -100
	local index = 0
	
	for unitToken, frame in pairs(self.frames) do
		if mode == "party" then
			-- Stack vertically
			frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xOffset, yOffset - (index * (self.settings.frameSize.height + self.settings.frameSpacing)))
		elseif mode == "raid" or mode == "smallRaid" then
			-- Group layout: 5-8 per column
			local groupSize = 5
			local row = index % groupSize
			local col = math.floor(index / groupSize)
			local xPos = xOffset + (col * (self.settings.frameSize.width + self.settings.frameSpacing))
			local yPos = yOffset - (row * (self.settings.frameSize.height + self.settings.frameSpacing))
			frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", xPos, yPos)
		end
		
		index = index + 1
	end
end

--- Highlight a frame (player moused over)
function InfinityHealer:HighlightFrame(frame)
	frame:SetBackdropBorderColor(1, 1, 0, 1) -- Yellow
end

--- Unhighlight a frame
function InfinityHealer:UnhighlightFrame(frame)
	frame:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8) -- Default
end

--- Clear all raid frames
function InfinityHealer:ClearRaidFrames()
	for unitToken, frame in pairs(self.frames) do
		if frame then
			frame:Hide()
			frame = nil
		end
	end
	self.frames = {}
end

-- ============================================================================
-- HEALTH UPDATES
-- ============================================================================

--- Update health display for a unit
function InfinityHealer:UpdateUnitHealth(unitToken)
	local frame = self.frames[unitToken]
	if not frame then
		return
	end
	
	local currentHealth = UnitHealth(unitToken)
	local maxHealth = UnitHealthMax(unitToken)
	
	if maxHealth == 0 then
		maxHealth = 1 -- Prevent divide by zero
	end
	
	local healthPercent = (currentHealth / maxHealth) * 100
	
	-- Update health bar
	frame.healthBar:SetMinMaxValues(0, maxHealth)
	frame.healthBar:SetValue(currentHealth)
	
	-- Color bar based on health
	if healthPercent > 50 then
		frame.healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 1) -- Green
	elseif healthPercent > 25 then
		frame.healthBar:SetStatusBarColor(1, 0.8, 0.2, 1) -- Yellow
	else
		frame.healthBar:SetStatusBarColor(0.8, 0.2, 0.2, 1) -- Red
	end
	
	-- Update text
	if self.settings.healthFormat == "PERCENT" then
		frame.healthText:SetText(math.floor(healthPercent) .. "%")
	elseif self.settings.healthFormat == "ACTUAL" then
		frame.healthText:SetText(math.floor(currentHealth / 1000) .. "k")
	else
		frame.healthText:SetText(math.floor(healthPercent) .. "% (" .. math.floor(currentHealth / 1000) .. "k)")
	end
end

-- ============================================================================
-- AURA MANAGEMENT
-- ============================================================================

--- Update auras (buffs/debuffs) for a unit
function InfinityHealer:UpdateUnitAuras(unitToken)
	local frame = self.frames[unitToken]
	if not frame then
		return
	end
	
	-- Clear existing aura display
	for i = 1, #frame.auras do
		frame.auras[i]:Hide()
	end
	
	-- Get auras
	local buffIndex = 1
	local debuffIndex = 1
	
	-- Display buffs (up to 3)
	for i = 1, UnitAuraCount(unitToken, "HELPFUL") do
		local name, icon, count, dispelType, duration, expirationTime = UnitAura(unitToken, i, "HELPFUL")
		
		if buffIndex <= 3 and name then
			self:DisplayAura(frame, buffIndex, name, icon, duration, expirationTime, "buff")
			buffIndex = buffIndex + 1
		end
	end
	
	-- Display debuffs (up to 3)
	for i = 1, UnitAuraCount(unitToken, "HARMFUL") do
		local name, icon, count, dispelType, duration, expirationTime = UnitAura(unitToken, i, "HARMFUL")
		
		if debuffIndex <= 3 and name then
			self:DisplayAura(frame, 10 + debuffIndex, name, icon, duration, expirationTime, "debuff")
			debuffIndex = debuffIndex + 1
		end
	end
end

--- Display a single aura icon
function InfinityHealer:DisplayAura(frame, index, name, icon, duration, expirationTime, auraType)
	-- This is simplified; in full implementation would create icon frames
	-- For now just track that aura exists
	if not frame.auras[index] then
		frame.auras[index] = {name = name, type = auraType, duration = duration}
	end
end

-- ============================================================================
-- CLICK-CASTING
-- ============================================================================

--- Handle frame click for spell casting
function InfinityHealer:OnFrameClick(frame, spellType)
	local unitToken = frame.unitToken
	
	if not unitToken then
		return
	end
	
	-- Get spell name based on click type
	local spellName = "Heal" -- Default
	
	if spellType == "heal" then
		spellName = "Heal"
	end
	
	-- Cast spell on target
	if UnitCanAssist("player", unitToken) then
		CastSpellByName(spellName)
		-- Wait a moment then cast on target
		C_Timer.After(0.1, function()
			if unitToken ~= "player" then
				SetCursorSpell(spellName)
				-- Target unit and cast
			end
		end)
	else
		InfinityUtils:Warning("Cannot assist " .. UnitName(unitToken), "Healer")
	end
end

-- ============================================================================
-- SPELL TRACKING
-- ============================================================================

--- Handle spell cast success
function InfinityHealer:OnSpellCast(spellId)
	-- Track spell for cooldown tracking
	-- This integrates with healing prediction system
end

-- ============================================================================
-- HEALING PREDICTION
-- ============================================================================

--- Register incoming heal from another player
function InfinityHealer:RegisterIncomingHeal(targetUnit, healAmount, healer, spellId)
	if not self.activeHeals[targetUnit] then
		self.activeHeals[targetUnit] = {}
	end
	
	table.insert(self.activeHeals[targetUnit], {
		amount = healAmount,
		healer = healer,
		spellId = spellId,
		timestamp = GetTime(),
		duration = 2, -- Assume instant-cast spells land within 2 seconds
	})
end

--- Get predicted health for a unit (actual + incoming heals)
function InfinityHealer:GetPredictedHealth(unitToken)
	local currentHealth = UnitHealth(unitToken)
	local maxHealth = UnitHealthMax(unitToken)
	local incomingHeals = 0
	
	if self.activeHeals[unitToken] then
		for _, heal in ipairs(self.activeHeals[unitToken]) do
			incomingHeals = incomingHeals + heal.amount
		end
	end
	
	local predictedHealth = math.min(currentHealth + incomingHeals, maxHealth)
	
	return predictedHealth, incomingHeals
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Toggle raid frames visibility
function InfinityHealer:ToggleFrames()
	for unitToken, frame in pairs(self.frames) do
		if frame:IsShown() then
			frame:Hide()
		else
			frame:Show()
		end
	end
end

--- Set frame scale
function InfinityHealer:SetFrameScale(scale)
	for unitToken, frame in pairs(self.frames) do
		frame:SetScale(scale)
	end
end

--- Set frame alpha (transparency)
function InfinityHealer:SetFrameAlpha(alpha)
	for unitToken, frame in pairs(self.frames) do
		frame:SetAlpha(alpha)
	end
end

return InfinityHealer
