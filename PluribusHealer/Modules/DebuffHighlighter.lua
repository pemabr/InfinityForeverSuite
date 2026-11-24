-- PluribusHealer - Debuff Highlighting Module
-- Highlights dangerous debuffs for quick identification and cleansing priority

local DebuffHighlighter = {}
_G.PluribusDebuffHighlighter = DebuffHighlighter

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

DebuffHighlighter.config = {
	enableHighlighting = true,
	updateInterval = 0.5,
	highlightIntensity = 1.0, -- 0.0-1.0
	showDebuffText = true,
	maxDebuffsPerUnit = 8,
}

-- Debuff categories and their priority
DebuffHighlighter.debuffTypes = {
	-- Type -> {color, priority, cleansableBy}
	["Poison"] = {
		color = {r = 0.4, g = 0.8, b = 0.2},
		priority = 2, -- Medium priority
		debuffs = {
			"Poison", "Envenom", "Poison Cloud", "Noxious Poison"
		}
	},
	["Disease"] = {
		color = {r = 0.8, g = 0.4, b = 0.2},
		priority = 2, -- Medium priority
		debuffs = {
			"Disease", "Plague", "Festering Strike", "Unholy Blight"
		}
	},
	["Curse"] = {
		color = {r = 0.6, g = 0.2, b = 0.8},
		priority = 3, -- Lower priority
		debuffs = {
			"Curse", "Curse of Recklessness", "Cursed", "Dire Curse"
		}
	},
	["Magic"] = {
		color = {r = 0.2, g = 0.4, b = 0.8},
		priority = 4, -- Lowest (usually just dispels)
		debuffs = {}
	},
	["Bleed"] = {
		color = {r = 1, g = 0.2, b = 0.2},
		priority = 1, -- High priority (immediate danger)
		debuffs = {
			"Bleed", "Lacerate", "Deep Wound", "Rend", "Bleeding"
		}
	},
	["Stun"] = {
		color = {r = 1, g = 1, b = 0},
		priority = 1, -- High priority (player incapacitated)
		debuffs = {
			"Stun", "Stunned", "Charge Stun", "Impact Stun"
		}
	},
	["Root"] = {
		color = {r = 0.8, g = 0.6, b = 0.2},
		priority = 2, -- Medium priority
		debuffs = {
			"Root", "Entangle", "Roots", "Ground"
		}
	},
	["Silence"] = {
		color = {r = 0.5, g = 0.2, b = 0.5},
		priority = 1, -- High priority (healer can't cast)
		debuffs = {
			"Silence", "Silenced", "Interrupt", "Silence Effect"
		}
	}
}

-- Critical debuffs that require immediate attention
DebuffHighlighter.criticalDebuffs = {
	-- Encounter-specific critical effects
	["Silence"] = true,
	["Stun"] = true,
	["Root"] = true,
	["Polymorph"] = true,
	["Mind Control"] = true,
	["Sleep"] = true,
	["Charm"] = true,
}

DebuffHighlighter.unitDebuffs = {} -- {unitToken = {debuffName, type, duration, ...}}
DebuffHighlighter.debuffFrames = {} -- Frames for visual display

-- ============================================================================
-- DEBUFF SCANNING
-- ============================================================================

--- Scan debuffs on a unit
function DebuffHighlighter:ScanUnitDebuffs(unitToken)
	if not UnitExists(unitToken) then
		return nil
	end
	
	local debuffs = {}
	local index = 1
	
	-- Scan all auras
	while true do
		local name, icon, count, debuffType, duration, expirationTime, caster, isStealable, nameplateShowAll, timeMod, isBossAura, casterIsPlayer, nameplateShowPersonal = PluribusUtils:GetUnitAura(unitToken, index, "HARMFUL")
		
		if not name then
			break
		end
		
		local debuffInfo = {
			name = name,
			icon = icon,
			count = count or 1,
			type = debuffType or "Magic",
			duration = duration or 0,
			expirationTime = expirationTime or 0,
			caster = caster,
			isStealable = isStealable or false,
			isBossAura = isBossAura or false,
			priority = self:GetDebuffPriority(name, debuffType),
			isCritical = self.criticalDebuffs[name] or false,
			timestamp = GetTime()
		}
		
		table.insert(debuffs, debuffInfo)
		index = index + 1
		
		if #debuffs >= self.config.maxDebuffsPerUnit then
			break
		end
	end
	
	-- Sort by priority (highest first)
	table.sort(debuffs, function(a, b)
		if a.priority ~= b.priority then
			return a.priority < b.priority -- Lower number = higher priority
		end
		return a.expirationTime < b.expirationTime -- Expiring soon comes first
	end)
	
	self.unitDebuffs[unitToken] = debuffs
	return debuffs
end

--- Get priority of a debuff
function DebuffHighlighter:GetDebuffPriority(debuffName, debuffType)
	-- Check if critical
	if self.criticalDebuffs[debuffName] then
		return 1
	end
	
	-- Check type priority
	if self.debuffTypes[debuffType] then
		return self.debuffTypes[debuffType].priority
	end
	
	-- Default priority
	return 5
end

--- Get color for debuff
function DebuffHighlighter:GetDebuffColor(debuffName, debuffType)
	-- Critical debuffs get red
	if self.criticalDebuffs[debuffName] then
		return {r = 1, g = 0.2, b = 0.2}
	end
	
	-- Type-based color
	if self.debuffTypes[debuffType] then
		return self.debuffTypes[debuffType].color
	end
	
	-- Default to blue
	return {r = 0.2, g = 0.4, b = 0.8}
end

-- ============================================================================
-- DEBUFF QUERYING
-- ============================================================================

--- Get all debuffs for a unit
function DebuffHighlighter:GetUnitDebuffs(unitToken)
	return self.unitDebuffs[unitToken] or {}
end

--- Get critical debuffs for a unit
function DebuffHighlighter:GetCriticalDebuffs(unitToken)
	local debuffs = self:GetUnitDebuffs(unitToken)
	local critical = {}
	
	for _, debuff in ipairs(debuffs) do
		if debuff.isCritical or debuff.priority <= 1 then
			table.insert(critical, debuff)
		end
	end
	
	return critical
end

--- Get dispellable debuffs
function DebuffHighlighter:GetDispellableDebuffs(unitToken, dispelType)
	-- dispelType: "Magic", "Curse", "Disease", "Poison", "Bleed"
	local debuffs = self:GetUnitDebuffs(unitToken)
	local dispellable = {}
	
	for _, debuff in ipairs(debuffs) do
		if debuff.type == dispelType then
			table.insert(dispellable, debuff)
		end
	end
	
	return dispellable
end

--- Get debuffs by type
function DebuffHighlighter:GetDebuffsByType(unitToken, debuffType)
	local debuffs = self:GetUnitDebuffs(unitToken)
	local typeDebuffs = {}
	
	for _, debuff in ipairs(debuffs) do
		if debuff.type == debuffType then
			table.insert(typeDebuffs, debuff)
		end
	end
	
	return typeDebuffs
end

--- Get debuffs expiring soonest
function DebuffHighlighter:GetExpiringSoonDebuffs(unitToken, timeThreshold)
	timeThreshold = timeThreshold or 5 -- Default 5 seconds
	local debuffs = self:GetUnitDebuffs(unitToken)
	local expiring = {}
	local now = GetTime()
	
	for _, debuff in ipairs(debuffs) do
		if debuff.expirationTime > 0 then
			local timeLeft = debuff.expirationTime - now
			if timeLeft > 0 and timeLeft <= timeThreshold then
				table.insert(expiring, {
					debuff = debuff,
					timeLeft = timeLeft
				})
			end
		end
	end
	
	-- Sort by time remaining (soonest first)
	table.sort(expiring, function(a, b)
		return a.timeLeft < b.timeLeft
	end)
	
	return expiring
end

-- ============================================================================
-- DEBUFF RECOMMENDATION ENGINE
-- ============================================================================

--- Get recommended dispels for a unit
function DebuffHighlighter:GetRecommendedDispels(unitToken)
	local recommendations = {}
	
	local critical = self:GetCriticalDebuffs(unitToken)
	for _, debuff in ipairs(critical) do
		table.insert(recommendations, {
			type = "CRITICAL",
			debuff = debuff,
			urgency = "IMMEDIATE",
			reason = "Critical effect must be removed"
		})
	end
	
	-- Check if unit is feared/silenced (healer can't help itself)
	local silenced = self:GetDebuffsByType(unitToken, "Silence")
	if #silenced > 0 then
		table.insert(recommendations, {
			type = "FUNCTIONAL",
			debuff = silenced[1],
			urgency = "HIGH",
			reason = "Healer is silenced and cannot cast"
		})
	end
	
	local feared = self:GetDebuffsByType(unitToken, "Fear")
	if #feared > 0 then
		table.insert(recommendations, {
			type = "FUNCTIONAL",
			debuff = feared[1],
			urgency = "HIGH",
			reason = "Unit is feared and cannot be healed effectively"
		})
	end
	
	-- Get expiring debuffs that should be cleansed before they expire
	local expiring = self:GetExpiringSoonDebuffs(unitToken, 3)
	for _, item in ipairs(expiring) do
		if item.debuff.type == "Bleed" or item.debuff.type == "Poison" or item.debuff.type == "Disease" then
			table.insert(recommendations, {
				type = "TIMING",
				debuff = item.debuff,
				urgency = "NORMAL",
				reason = "Debuff expiring soon",
				timeLeft = item.timeLeft
			})
		end
	end
	
	return recommendations
end

--- Get priority score for healing (considering debuffs)
-- Higher score = more urgent heal needed
function DebuffHighlighter:GetUnitHealingUrgency(unitToken)
	local health = UnitHealth(unitToken) or 100
	local maxHealth = UnitHealthMax(unitToken) or 100
	local healthPercent = (health / maxHealth) * 100
	
	-- Base score from health
	local score = (100 - healthPercent) / 100 * 50 -- Max 50 points from health
	
	-- Add points for critical debuffs
	local critical = self:GetCriticalDebuffs(unitToken)
	score = score + (#critical * 25) -- 25 points per critical debuff
	
	-- Add points for expiring debuffs
	local expiring = self:GetExpiringSoonDebuffs(unitToken, 3)
	score = score + (#expiring * 10) -- 10 points per expiring debuff
	
	return score
end

-- ============================================================================
-- VISUAL HIGHLIGHTING
-- ============================================================================

--- Create debuff highlight frame
function DebuffHighlighter:CreateDebuffFrame(parent, debuff)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(20, 20)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	})
	
	-- Set color
	local color = self:GetDebuffColor(debuff.name, debuff.type)
	frame:SetBackdropColor(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.8)
	frame:SetBackdropBorderColor(color.r, color.g, color.b, 1)
	
	-- Add icon
	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetAllPoints(frame)
	icon:SetTexture(debuff.icon)
	
	-- Add count text if stacked
	if debuff.count > 1 then
		local countText = frame:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		countText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
		countText:SetText(tostring(debuff.count))
	end
	
	-- Add duration text if requested
	if self.config.showDebuffText and debuff.duration > 0 then
		local durationText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		durationText:SetPoint("TOP", frame, "TOP", 0, -2)
		durationText:SetText(string.format("%.1fs", debuff.duration))
	end
	
	-- Store debuff info
	frame.debuff = debuff
	
	return frame
end

--- Update debuff visual on frame
function DebuffHighlighter:UpdateDebuffFrame(frame, unitToken)
	-- This would be called by HealerFrames to update debuff displays
	local debuffs = self:GetUnitDebuffs(unitToken)
	
	-- Clear existing debuff displays
	if frame.debuffContainer then
		frame.debuffContainer:Hide()
	end
	
	-- Create new container if needed
	if not frame.debuffContainer then
		frame.debuffContainer = CreateFrame("Frame", nil, frame)
		frame.debuffContainer:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 2)
	end
	
	frame.debuffContainer:Show()
	
	-- Display critical debuffs
	local critical = self:GetCriticalDebuffs(unitToken)
	for i = 1, math.min(3, #critical) do -- Show max 3
		if not frame.debuffContainer.debuffFrames then
			frame.debuffContainer.debuffFrames = {}
		end
		
		if not frame.debuffContainer.debuffFrames[i] then
			frame.debuffContainer.debuffFrames[i] = self:CreateDebuffFrame(frame.debuffContainer, critical[i])
		end
		
		frame.debuffContainer.debuffFrames[i]:SetPoint("LEFT", frame.debuffContainer, "LEFT", (i-1) * 22, 0)
		frame.debuffContainer.debuffFrames[i].debuff = critical[i]
	end
end

-- ============================================================================
-- UPDATE LOOP
-- ============================================================================

function DebuffHighlighter:Initialize()
	PluribusUtils:Info("DebuffHighlighter initializing...", "Debuff")
	
	-- Create update frame
	local updateFrame = CreateFrame("Frame")
	local elapsed = 0
	
	updateFrame:SetScript("OnUpdate", function(f, delta)
		elapsed = elapsed + delta
		
		if elapsed >= self.config.updateInterval then
			self:UpdateAllDebuffs()
			elapsed = 0
		end
	end)
	
	PluribusUtils:Info("DebuffHighlighter initialized", "Debuff")
end

--- Update debuffs for all raid members
function DebuffHighlighter:UpdateAllDebuffs()
	local groupSize = GetNumGroupMembers()
	
	if groupSize == 0 then
		return
	end
	
	for i = 1, groupSize do
		local unitToken
		if groupSize <= 5 then
			unitToken = i == 1 and "player" or ("party" .. (i - 1))
		else
			unitToken = "raid" .. i
		end
		
		if UnitExists(unitToken) then
			self:ScanUnitDebuffs(unitToken)
		end
	end
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

if PluribusCommandRegistry then
	PluribusCommandRegistry:RegisterCommand("debuffs", function(args)
		if not args or #args == 0 then
			local target = "target"
			if UnitExists(target) then
				local debuffs = DebuffHighlighter:GetUnitDebuffs(target)
				if #debuffs > 0 then
					print("|cffff4444Debuffs on " .. UnitName(target) .. ":|r")
					for i, debuff in ipairs(debuffs) do
						print(string.format("  %d. %s (%s) - %d%%", i, debuff.name, debuff.type, debuff.priority * 20))
					end
				else
					print("No debuffs")
				end
			else
				print("No target selected")
			end
		elseif args[1] == "critical" then
			local target = "target"
			if UnitExists(target) then
				local critical = DebuffHighlighter:GetCriticalDebuffs(target)
				if #critical > 0 then
					print("|cffff0000CRITICAL DEBUFFS:|r")
					for _, debuff in ipairs(critical) do
						print("  - " .. debuff.name)
					end
				else
					print("No critical debuffs")
				end
			end
		end
	end, {"debuff"})
end

print("[INFO] Debuff Highlighter module loaded successfully")
