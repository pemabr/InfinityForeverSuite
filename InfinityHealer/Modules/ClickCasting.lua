-- Click-Casting System Module
-- Enables spell casting on raid frames with modifier key support

local InfinityClickCast = {}
_G.InfinityClickCast = InfinityClickCast

-- Click-cast configuration
InfinityClickCast.config = {
	enableClickCast = true,
	castOnMouseover = true,
	castOnMouseoverDelay = 0.05, -- seconds
	showCastNotifications = true,
	queueSpells = false,
	queueTimeout = 2,
}

-- Spell bindings: {button = {spell, modifier = {spell, ...}}}
InfinityClickCast.spellBindings = {
	["RightButton"] = {
		spell = "Heal",
		["SHIFT"] = "Renew",
		["CTRL"] = "Power Word: Shield",
		["ALT"] = "Prayer of Mending",
	},
	["MiddleButton"] = {
		spell = "Flash Heal",
		["SHIFT"] = "Holy Fire",
		["CTRL"] = "Smite",
	},
}

-- Active casts and queues
InfinityClickCast.activeCasts = {} -- {unitToken = {spellName, castTime, startTime}}
InfinityClickCast.castQueue = {} -- Queue for spells to cast
InfinityClickCast.mouseoverTarget = nil
InfinityClickCast.lastClickTime = 0

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

--- Initialize click-casting system
function InfinityClickCast:Initialize()
	InfinityUtils:Info("Click-casting system initialized", "ClickCast")
	
	-- Load saved spell bindings
	self.spellBindings = InfinityStorageManager:GetFeatureSettings("clickcast_bindings") or self.spellBindings
end

--- Register click-cast handler on a frame
function InfinityClickCast:SetupClickCasting(frame, unitToken)
	if not self.config.enableClickCast then
		return
	end
	
	-- Store unit token on frame
	frame.unitToken = unitToken
	
	-- Left button (primary heal)
	frame:SetScript("OnClick", function(f, button, down)
		if down then
			InfinityClickCast:OnFrameClick(f, button)
		end
	end)
	
	-- Right button context menu
	frame:SetScript("OnMouseDown", function(f, button)
		if button == "RightButton" then
			InfinityClickCast:OnFrameClick(f, button)
		end
	end)
	
	-- Mouseover targeting
	frame:SetScript("OnEnter", function(f)
		InfinityClickCast.mouseoverTarget = f.unitToken
	end)
	
	frame:SetScript("OnLeave", function(f)
		if InfinityClickCast.mouseoverTarget == f.unitToken then
			InfinityClickCast.mouseoverTarget = nil
		end
	end)
end

-- ============================================================================
-- SPELL BINDING
-- ============================================================================

--- Get spell name for a click
-- @param button: string ("LeftButton", "RightButton", etc.)
-- @return spellName: string or nil
function InfinityClickCast:GetSpellForClick(button)
	local binding = self.spellBindings[button]
	if not binding then
		return nil
	end
	
	-- Check for modifier keys
	local modifier = nil
	if IsShiftKeyDown() then
		modifier = "SHIFT"
	elseif IsControlKeyDown() then
		modifier = "CTRL"
	elseif IsAltKeyDown() then
		modifier = "ALT"
	end
	
	-- Get spell based on modifiers
	if modifier and binding[modifier] then
		return binding[modifier]
	else
		return binding.spell
	end
end

--- Set spell binding for a button/modifier combination
-- @param button: string
-- @param spellName: string
-- @param modifier: string or nil (nil = default, "SHIFT", "CTRL", "ALT")
function InfinityClickCast:SetBinding(button, spellName, modifier)
	if not self.spellBindings[button] then
		self.spellBindings[button] = {spell = "Heal"}
	end
	
	if modifier then
		self.spellBindings[button][modifier] = spellName
	else
		self.spellBindings[button].spell = spellName
	end
	
	-- Save bindings
	InfinityStorageManager:SetFeatureSettings("clickcast_bindings", self.spellBindings)
	
	InfinityUtils:Info("Binding set: " .. button .. (modifier and (" +" .. modifier) or "") .. " → " .. spellName, "ClickCast")
end

--- Get all bindings
-- @return bindings: table
function InfinityClickCast:GetAllBindings()
	return self.spellBindings
end

--- Reset bindings to defaults
function InfinityClickCast:ResetBindings()
	self.spellBindings = {
		["RightButton"] = {
			spell = "Heal",
			["SHIFT"] = "Renew",
			["CTRL"] = "Power Word: Shield",
			["ALT"] = "Prayer of Mending",
		},
		["MiddleButton"] = {
			spell = "Flash Heal",
			["SHIFT"] = "Holy Fire",
			["CTRL"] = "Smite",
		},
	}
	
	InfinityStorageManager:SetFeatureSettings("clickcast_bindings", self.spellBindings)
	InfinityUtils:Info("Click-cast bindings reset to defaults", "ClickCast")
end

-- ============================================================================
-- CLICK HANDLING
-- ============================================================================

--- Handle frame click event
-- @param frame: frame object
-- @param button: string ("LeftButton", "RightButton", etc.)
function InfinityClickCast:OnFrameClick(frame, button)
	local unitToken = frame.unitToken
	if not unitToken or not UnitExists(unitToken) then
		return
	end
	
	-- Prevent double-clicking
	local currentTime = GetTime()
	if currentTime - self.lastClickTime < 0.05 then
		return
	end
	self.lastClickTime = currentTime
	
	-- Get spell for this click
	local spellName = self:GetSpellForClick(button)
	
	if not spellName then
		InfinityUtils:Warning("No spell bound to " .. button, "ClickCast")
		return
	end
	
	-- Check if spell exists and is castable
	local spellId = self:GetSpellID(spellName)
	if not spellId then
		InfinityUtils:Warning("Spell not found: " .. spellName, "ClickCast")
		return
	end
	
	-- Cast spell
	self:CastSpellOnUnit(spellName, unitToken)
end

--- Cast a spell on a specific unit
-- @param spellName: string
-- @param unitToken: string
-- @return success: boolean
function InfinityClickCast:CastSpellOnUnit(spellName, unitToken)
	-- Check if player can cast
	if UnitIsCharmed("player") then
		return false
	end
	
	-- Check range
	if not UnitInRange(unitToken) then
		if self.config.showCastNotifications then
			InfinityUtils:Warning(UnitName(unitToken) .. " is out of range", "ClickCast")
		end
		return false
	end
	
	-- Check line of sight (simplified)
	if not self:CheckLineOfSight(unitToken) then
		if self.config.showCastNotifications then
			InfinityUtils:Warning("No line of sight to " .. UnitName(unitToken), "ClickCast")
		end
		return false
	end
	
	-- Target the unit temporarily
	local originalTarget = UnitExists("target") and UnitName("target") or nil
	TargetUnit(unitToken)
	
	-- Cast spell
	CastSpellByName(spellName)
	
	-- Restore original target after a brief delay
	if originalTarget then
		C_Timer.After(0.1, function()
			TargetUnit(originalTarget)
		end)
	else
		C_Timer.After(0.1, function()
			ClearTarget()
		end)
	end
	
	-- Track cast
	self:TrackCast(spellName, unitToken)
	
	return true
end

--- Track an active cast for cooldown/timing
-- @param spellName: string
-- @param unitToken: string
function InfinityClickCast:TrackCast(spellName, unitToken)
	local castTime = self:GetSpellCastTime(spellName)
	
	self.activeCasts[unitToken] = {
		spell = spellName,
		castTime = castTime,
		startTime = GetTime(),
		targetUnit = unitToken,
	}
	
	-- Publish event for UI updates
	InfinityMessaging:Publish(INFINITY_EVENTS.DATA_CHANGED, "clickcast", "spell_cast", {
		spell = spellName,
		unit = unitToken,
		castTime = castTime,
	})
end

-- ============================================================================
-- SPELL UTILITIES
-- ============================================================================

--- Get spell ID by name
-- @param spellName: string
-- @return spellId: number or nil
function InfinityClickCast:GetSpellID(spellName)
	-- Search player spellbook
	for i = 1, GetNumSpells() do
		local spell, rank = GetSpellName(i, BOOKTYPE_SPELL)
		if spell == spellName then
			return GetSpellLink(i, BOOKTYPE_SPELL)
		end
	end
	
	return nil
end

--- Get spell cast time
-- @param spellName: string
-- @return castTime: number (seconds)
function InfinityClickCast:GetSpellCastTime(spellName)
	-- Simplified - instant cast = 0, otherwise ~2 sec default
	-- Full implementation would use spell data
	local instantSpells = {
		"Renew", "Power Word: Shield", "Prayer of Mending",
		"Flash Heal", "Holy Fire", "Smite"
	}
	
	for _, spell in ipairs(instantSpells) do
		if spell == spellName then
			return 0
		end
	end
	
	return 2.0 -- Default cast time
end

--- Get spell range in yards
-- @param spellName: string
-- @return range: number (yards)
function InfinityClickCast:GetSpellRange(spellName)
	-- Simplified ranges
	local ranges = {
		["Heal"] = 40,
		["Flash Heal"] = 40,
		["Holy Fire"] = 40,
		["Smite"] = 40,
		["Power Word: Shield"] = 40,
		["Prayer of Mending"] = 40,
		["Renew"] = 40,
	}
	
	return ranges[spellName] or 40
end

--- Check line of sight to target
-- @param unitToken: string
-- @return hasLOS: boolean
function InfinityClickCast:CheckLineOfSight(unitToken)
	-- Simplified LOS check
	-- Full implementation would use raycasts
	
	local playerX, playerY = GetPlayerMapPosition("player")
	local unitX, unitY = GetPlayerMapPosition(unitToken)
	
	if not playerX or not unitX then
		return true -- Assume can see if no position data
	end
	
	-- Simple distance check (not true LOS)
	local distance = math.sqrt((playerX - unitX)^2 + (playerY - unitY)^2)
	
	return distance < 1 -- Rough check
end

-- ============================================================================
-- HEALING QUEUE
-- ============================================================================

--- Queue a spell to cast (if spell queue enabled)
-- @param spellName: string
-- @param unitToken: string
function InfinityClickCast:QueueSpell(spellName, unitToken)
	if not self.config.queueSpells then
		return false
	end
	
	table.insert(self.castQueue, {
		spell = spellName,
		unit = unitToken,
		queueTime = GetTime(),
	})
	
	InfinityUtils:Debug("Spell queued: " .. spellName .. " on " .. UnitName(unitToken), "ClickCast")
	
	return true
end

--- Process spell queue
function InfinityClickCast:ProcessQueue()
	if #self.castQueue == 0 then
		return
	end
	
	local currentTime = GetTime()
	
	-- Check if first queued spell can be cast
	local entry = self.castQueue[1]
	
	if currentTime - entry.queueTime > self.config.queueTimeout then
		table.remove(self.castQueue, 1)
		return
	end
	
	-- Try to cast
	if self:CastSpellOnUnit(entry.spell, entry.unit) then
		table.remove(self.castQueue, 1)
	end
end

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

--- Get current configuration
-- @return config: table
function InfinityClickCast:GetConfig()
	return self.config
end

--- Set configuration option
-- @param key: string
-- @param value: any
function InfinityClickCast:SetConfig(key, value)
	if self.config[key] ~= nil then
		self.config[key] = value
		InfinityStorageManager:SetFeatureSettings("clickcast_config", self.config)
		InfinityUtils:Info(key .. " = " .. tostring(value), "ClickCast")
	end
end

--- Enable/disable click-casting
-- @param enabled: boolean
function InfinityClickCast:SetEnabled(enabled)
	self.config.enableClickCast = enabled
	InfinityUtils:Info("Click-casting " .. (enabled and "enabled" or "disabled"), "ClickCast")
end

return InfinityClickCast
