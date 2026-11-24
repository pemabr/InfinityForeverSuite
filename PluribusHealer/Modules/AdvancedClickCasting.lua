-- PluribusHealer - Advanced Click-Casting System
-- Enables healing spells to be cast by clicking on raid frames with modifier keys

local ClickCaster = {}
_G.PluribusClickCaster = ClickCaster

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

ClickCaster.config = {
	enabled = true,
	leftClick = "heal", -- Left click action
	rightClick = "dispel", -- Right click action
	middleClick = "shield", -- Middle click action
	
	-- Modifier keys
	shift = "smallheal",
	ctrl = "bigheal",
	alt = "preventive",
	
	-- Auto-cast settings
	autoRepeat = true,
	queueCasts = true,
	maxQueueSize = 10,
	
	-- Safety settings
	enableSafeMode = true, -- Don't cast if out of range/mana
	showCastBar = true,
}

ClickCaster.spellBindings = {
	-- action -> {spellName, spellId}
	heal = {spellName = "Heal", spellId = 743},
	smallheal = {spellName = "Lesser Heal", spellId = 2050},
	bigheal = {spellName = "Greater Heal", spellId = 2060},
	dispel = {spellName = "Dispel Magic", spellId = 988},
	shield = {spellName = "Power Word: Shield", spellId = 1706},
	preventive = {spellName = "Renew", spellId = 139},
}

ClickCaster.castQueue = {} -- {target, spell, timestamp}
ClickCaster.isActive = false
ClickCaster.currentCast = nil

-- ============================================================================
-- SPELL BINDING
-- ============================================================================

local function SafeGetSpellID(spellName)
	if not spellName then return nil end
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(spellName)
		return info and info.spellID or nil
	elseif GetSpellInfo then
		return select(7, GetSpellInfo(spellName))
	end
	return nil
end

--- Bind a spell to a click action
function ClickCaster:BindSpell(action, spellName, spellId)
	spellId = spellId or SafeGetSpellID(spellName)
	
	self.spellBindings[action] = {
		spellName = spellName,
		spellId = spellId
	}
	
	PluribusUtils:Info(string.format("Bound %s to %s", spellName, action), "ClickCast")
end

--- Get spell for action
function ClickCaster:GetSpellForAction(action)
	return self.spellBindings[action]
end

--- Get action from modifier keys
function ClickCaster:GetActionFromModifiers()
	if IsControlKeyDown() then
		return "ctrl"
	elseif IsShiftKeyDown() then
		return "shift"
	elseif IsAltKeyDown() then
		return "alt"
	end
	return nil
end

--- Handle frame click
function ClickCaster:OnFrameClick(frame, button)
	if not self.config.enabled then
		return
	end
	
	local unitToken = frame.unitToken
	if not UnitExists(unitToken) then
		return
	end
	
	-- Get action based on button and modifiers
	local action = nil
	local modifier = self:GetActionFromModifiers()
	
	if modifier then
		action = self.config[modifier]
	else
		if button == "LeftButton" then
			action = self.config.leftClick
		elseif button == "RightButton" then
			action = self.config.rightClick
		elseif button == "MiddleButton" then
			action = self.config.middleClick
		end
	end
	
	if action then
		self:CastSpellOnTarget(action, unitToken)
	end
end

-- ============================================================================
-- SPELL CASTING
-- ============================================================================

--- Cast spell on target
function ClickCaster:CastSpellOnTarget(action, unitToken)
	local spell = self:GetSpellForAction(action)
	
	if not spell then
		PluribusUtils:Warning("No spell bound to action: " .. action, "ClickCast")
		return
	end
	
	-- Safety checks
	if self.config.enableSafeMode then
		if not self:CanCastSpell(spell.spellName, unitToken) then
			PluribusUtils:Debug("Cannot cast " .. spell.spellName .. " on " .. UnitName(unitToken), "ClickCast")
			return
		end
	end
	
	-- Queue or cast
	if self.config.queueCasts and self.isActive then
		self:QueueSpellCast(action, unitToken, spell)
	else
		self:ExecuteSpellCast(spell, unitToken)
	end
end

--- Execute spell cast immediately
function ClickCaster:ExecuteSpellCast(spell, unitToken)
	-- Set target
	SpellStopCasting() -- Cancel current cast
	
	if unitToken ~= "player" then
		TargetUnit(unitToken)
	end
	
	-- Cast spell
	CastSpellByName(spell.spellName, unitToken)
	
	-- Mark as active
	self.isActive = true
	self.currentCast = {
		spell = spell,
		target = unitToken,
		timestamp = GetTime()
	}
	
	PluribusUtils:Debug(string.format("Casting %s on %s", spell.spellName, UnitName(unitToken)), "ClickCast")
end

--- Queue spell cast for later
function ClickCaster:QueueSpellCast(action, unitToken, spell)
	if #self.castQueue >= self.config.maxQueueSize then
		PluribusUtils:Warning("Cast queue full", "ClickCast")
		return
	end
	
	table.insert(self.castQueue, {
		action = action,
		target = unitToken,
		spell = spell,
		timestamp = GetTime()
	})
end

--- Process queued casts
function ClickCaster:ProcessCastQueue()
	if #self.castQueue == 0 or self.isActive then
		return
	end
	
	local next = table.remove(self.castQueue, 1)
	if next then
		self:ExecuteSpellCast(next.spell, next.target)
	end
end

--- Check if can cast spell on target
function ClickCaster:CanCastSpell(spellName, unitToken)
	if not UnitExists(unitToken) then
		return false
	end
	
	-- Check mana
	local mana = (UnitPower and UnitPower("player", 0)) or (UnitMana and UnitMana("player")) or 0
	local maxMana = (UnitPowerMax and UnitPowerMax("player", 0)) or (UnitMaxMana and UnitMaxMana("player")) or 1
	if maxMana > 0 and mana < (maxMana * 0.1) then -- Less than 10% mana
		return false
	end
	
	-- Check if spell is off cooldown
	local spellId = SafeGetSpellID(spellName)
	if spellId then
		local start, duration = 0, 0
		if C_Spell and C_Spell.GetSpellCooldown then
			local cd = C_Spell.GetSpellCooldown(spellId)
			if cd then
				start, duration = cd.startTime or 0, cd.duration or 0
			end
		elseif GetSpellCooldown then
			start, duration = GetSpellCooldown(spellId)
		end
		if (start or 0) > 0 and (duration or 0) > 0 then
			return false
		end
	end
	
	-- Check range
	if unitToken ~= "player" then
		local inRange = true
		if C_Spell and C_Spell.IsSpellInRange then
			local r = C_Spell.IsSpellInRange(spellName, unitToken)
			if r == false or r == 0 then inRange = false end
		elseif IsSpellInRange then
			local r = IsSpellInRange(spellName, unitToken)
			if r == 0 or r == false then inRange = false end
		end
		if not inRange then
			return false
		end
	end
	
	return true
end

-- ============================================================================
-- CAST BAR
-- ============================================================================

--- Create cast bar for frame
function ClickCaster:CreateCastBar(frame)
	if not self.config.showCastBar then
		return
	end
	
	local castBar = CreateFrame("StatusBar", nil, frame)
	castBar:SetSize(frame:GetWidth(), 2)
	castBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, -2)
	castBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	castBar:SetStatusBarColor(1, 1, 0, 1) -- Yellow for casting
	castBar:Hide()
	
	frame.castBar = castBar
	return castBar
end

--- Show cast bar
function ClickCaster:ShowCastBar(frame, duration)
	if not frame.castBar then
		self:CreateCastBar(frame)
	end
	
	frame.castBar:SetValue(100)
	frame.castBar:Show()
	
	-- Animate cast bar
	local startTime = GetTime()
	local castFrame = CreateFrame("Frame")
	
	castFrame:SetScript("OnUpdate", function(f, delta)
		local elapsed = GetTime() - startTime
		local progress = math.min(100, (elapsed / duration) * 100)
		
		frame.castBar:SetValue(progress)
		
		if elapsed >= duration then
			frame.castBar:Hide()
			f:Hide()
		end
	end)
end

-- ============================================================================
-- INTEGRATION WITH HEALER FRAMES
-- ============================================================================

--- Register click handler on frame
function ClickCaster:RegisterFrameClick(frame)
	frame:SetScript("OnMouseDown", function(f, button)
		ClickCaster:OnFrameClick(f, button)
	end)
end

--- Register all frames for click-casting
function ClickCaster:RegisterAllFrames()
	if not PluribusFrameRenderer then
		return
	end
	
	for unitToken, frame in pairs(PluribusFrameRenderer.frames) do
		self:RegisterFrameClick(frame)
	end
end

-- ============================================================================
-- KEYBIND SYSTEM
-- ============================================================================

--- Register keybind
function ClickCaster:RegisterKeybind(action, key)
	-- This would require secure command registration
	-- For now, we'll use simple in-game keybinds
	
	SetBinding(key, "CLICKCAST_" .. action:upper())
	SaveBindings(GetCurrentBindingSet())
	
	PluribusUtils:Info(string.format("Bound %s to %s", action, key), "ClickCast")
end

--- Handle keybind press
function ClickCaster:OnKeybindPress(action)
	local target = GetMouseFocus()
	if not target or not target.unitToken then
		target = "target"
	else
		target = target.unitToken
	end
	
	self:CastSpellOnTarget(action, target)
end

-- ============================================================================
-- STATUS & DIAGNOSTICS
-- ============================================================================

--- Get cast queue status
function ClickCaster:GetQueueStatus()
	return {
		queueSize = #self.castQueue,
		isActive = self.isActive,
		currentCast = self.currentCast,
		maxQueueSize = self.config.maxQueueSize
	}
end

--- Print spell bindings
function ClickCaster:PrintBindings()
	print("|cff00ccffClick-Cast Bindings:|r")
	
	for action, spell in pairs(self.spellBindings) do
		print(string.format("  %s: %s", action, spell.spellName))
	end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

function ClickCaster:Initialize()
	PluribusUtils:Info("ClickCaster initializing...", "ClickCast")
	
	-- Create event frame for cast complete detection
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("SPELL_CAST_SUCCESS")
	eventFrame:RegisterEvent("SPELL_CAST_FAILED")
	
	eventFrame:SetScript("OnEvent", function(f, event, ...)
		if event == "SPELL_CAST_SUCCESS" then
			self.isActive = false
			self:ProcessCastQueue()
		elseif event == "SPELL_CAST_FAILED" then
			self.isActive = false
			PluribusUtils:Warning("Spell cast failed", "ClickCast")
		end
	end)
	
	-- Register frames when group updates
	local groupFrame = CreateFrame("Frame")
	groupFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	
	groupFrame:SetScript("OnEvent", function(f, event)
		self:RegisterAllFrames()
	end)
	
	PluribusUtils:Info("ClickCaster initialized", "ClickCast")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

if PluribusCommandRegistry then
	PluribusCommandRegistry:RegisterCommand("clickcast", function(args)
		if not args or #args == 0 then
			ClickCaster:PrintBindings()
		elseif args[1] == "bind" and args[2] and args[3] then
			ClickCaster:BindSpell(args[2], args[3])
		elseif args[1] == "queue" then
			local status = ClickCaster:GetQueueStatus()
			print(string.format("Cast Queue: %d/%d | Active: %s", 
				status.queueSize, status.maxQueueSize, 
				status.isActive and "Yes" or "No"))
		end
	end, {"cast", "click"})
end

print("[INFO] Click-Casting system loaded successfully")
