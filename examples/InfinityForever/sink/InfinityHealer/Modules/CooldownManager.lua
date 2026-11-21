-- Cooldown Manager Module
-- Tracks healing cooldowns and spell availability

local CooldownManager = {
	cooldowns = {}, -- {spellId = {expireTime, duration}}
	spells = {}, -- {spellId = {name, icon, cooldown, castTime}}
	
	config = {
		trackGlobalCooldown = true,
		notifyOffCooldown = true,
		minimumNotifyThreshold = 5, -- seconds
	},
	
	globalCooldown = {
		startTime = 0,
		duration = 1.5,
	},
}

_G.InfinityHealerCooldownManager = CooldownManager

-- Initialize cooldown tracking
function CooldownManager:Initialize()
	InfinityUtils:Info("Cooldown manager initialized", "Healer")
	
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	frame:RegisterEvent("UNIT_SPELLCAST_SENT")
	
	frame:SetScript("OnEvent", function(f, event, ...)
		if event == "UNIT_SPELLCAST_SENT" then
			CooldownManager:OnSpellCast(...)
		elseif event == "SPELL_UPDATE_COOLDOWN" then
			CooldownManager:OnCooldownUpdate()
		end
	end)
	
	-- Enable periodic cooldown checks
	C_Timer.NewTicker(0.5, function()
		CooldownManager:UpdateCooldowns()
	end)
end

-- Called when spell is cast
function CooldownManager:OnSpellCast(unit, spellCast, spellId)
	if unit == "player" and spellId then
		-- Record spell info
		if not self.spells[spellId] then
			local name, _, icon = GetSpellInfo(spellId)
			self.spells[spellId] = {
				name = name,
				icon = icon,
				spellId = spellId,
			}
		end
		
		-- Set global cooldown
		self.globalCooldown.startTime = GetTime()
		self.globalCooldown.duration = 1.5
		
		-- Start cooldown for this spell
		local cooldown = select(1, GetSpellCooldown(spellId))
		if cooldown and cooldown > 0 then
			self:SetCooldown(spellId, cooldown)
		end
	end
end

-- Called when cooldown updates
function CooldownManager:OnCooldownUpdate()
	-- Scan all healing spells for cooldown changes
	for spellId, _ in pairs(self.spells) do
		local cooldown = select(1, GetSpellCooldown(spellId))
		if cooldown and cooldown > 0 then
			self:SetCooldown(spellId, cooldown)
		else
			-- Spell is off cooldown
			if self.cooldowns[spellId] then
				self:OnSpellAvailable(spellId)
				self.cooldowns[spellId] = nil
			end
		end
	end
end

-- Set spell cooldown
function CooldownManager:SetCooldown(spellId, duration)
	self.cooldowns[spellId] = {
		expireTime = GetTime() + duration,
		duration = duration,
		startTime = GetTime(),
	}
end

-- Called when spell comes off cooldown
function CooldownManager:OnSpellAvailable(spellId)
	if self.config.notifyOffCooldown then
		local spellName = self.spells[spellId] and self.spells[spellId].name or "Unknown"
		InfinityUtils:Info(spellName .. " is available", "Healer")
	end
	
	InfinityMessaging:Publish("spell_available", spellId)
end

-- Get cooldown for spell
function CooldownManager:GetCooldown(spellId)
	if self.cooldowns[spellId] then
		local remaining = self.cooldowns[spellId].expireTime - GetTime()
		return math.max(0, remaining)
	end
	return 0
end

-- Check if spell is available
function CooldownManager:IsSpellAvailable(spellId)
	return self:GetCooldown(spellId) <= 0
end

-- Get global cooldown remaining
function CooldownManager:GetGlobalCooldown()
	local remaining = (self.globalCooldown.startTime + self.globalCooldown.duration) - GetTime()
	return math.max(0, remaining)
end

-- Get all cooldowns
function CooldownManager:GetAllCooldowns()
	local cooldowns = {}
	
	for spellId, cd in pairs(self.cooldowns) do
		local remaining = cd.expireTime - GetTime()
		if remaining > 0 then
			cooldowns[spellId] = {
				spellId = spellId,
				spellName = self.spells[spellId] and self.spells[spellId].name or "Unknown",
				remaining = remaining,
				duration = cd.duration,
				percentage = (1 - (remaining / cd.duration)) * 100,
			}
		end
	end
	
	return cooldowns
end

-- Get cooldown status for all important healing cooldowns
function CooldownManager:GetImportantCooldowns()
	local important = {
		"Power Word: Mend",
		"Prayer of Healing",
		"Renew",
		"Heal",
		"Flash Heal",
		"Holy Fire",
	}
	
	local cooldowns = {}
	
	for _, spellName in ipairs(important) do
		local spellId = FindSpellIdByName(spellName)
		if spellId then
			local cd = self:GetCooldown(spellId)
			table.insert(cooldowns, {
				name = spellName,
				remaining = cd,
				available = cd <= 0,
			})
		end
	end
	
	return cooldowns
end

-- Update all cooldowns (periodic check)
function CooldownManager:UpdateCooldowns()
	for spellId, cd in pairs(self.cooldowns) do
		if cd.expireTime <= GetTime() then
			self:OnSpellAvailable(spellId)
			self.cooldowns[spellId] = nil
		end
	end
end

-- Display cooldown status
function CooldownManager:DisplayCooldowns()
	print("|cffffd700=== SPELL COOLDOWNS ===|r")
	
	local gcd = self:GetGlobalCooldown()
	if gcd > 0 then
		print("GCD: " .. string.format("%.2f", gcd) .. "s")
	else
		print("GCD: Ready")
	end
	
	print("\n|cffccccccImportant Cooldowns:|r")
	local important = self:GetImportantCooldowns()
	for _, cd in ipairs(important) do
		if cd.available then
			print("  " .. cd.name .. ": |cff00ff00Ready|r")
		else
			print("  " .. cd.name .. ": " .. string.format("%.1f", cd.remaining) .. "s")
		end
	end
end

return CooldownManager
