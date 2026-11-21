-- InfinityHealer - Optimized Raid Frame Renderer
-- Renders 40-man raid frames with efficient layout and update system

local FrameRenderer = {}
_G.InfinityFrameRenderer = FrameRenderer

-- ============================================================================
-- CONFIGURATION
-- ============================================================================

FrameRenderer.config = {
	-- Frame dimensions
	frameWidth = 90,
	frameHeight = 35,
	groupSpacing = 15,
	playerSpacing = 2,
	
	-- Layout modes
	layoutMode = "raid", -- "raid", "party", "group", "compact"
	
	-- Update settings
	healthUpdateRate = 0.1, -- 100ms = 10 FPS
	statusUpdateRate = 0.05, -- 50ms = 20 FPS
	maxFramesPerRender = 40, -- Don't render more than 40 at once
	
	-- Visual settings
	enableNamePlates = true,
	enableHealth = true,
	enableMana = true,
	enableDebuffs = true,
	enableBuffs = true,
	enableRoleIcons = true,
	
	-- Colors
	colors = {
		health = {r = 0.2, g = 0.8, b = 0.2},
		mana = {r = 0.3, g = 0.6, b = 1},
		absorb = {r = 1, g = 0.84, b = 0},
		threat = {r = 1, g = 0.2, b = 0.2},
	}
}

FrameRenderer.frames = {} -- {unitToken = frame}
FrameRenderer.groups = {} -- {groupNum = {frame1, frame2, ...}}
FrameRenderer.mainWindow = nil
FrameRenderer.lastUpdate = 0

-- ============================================================================
-- FRAME CREATION
-- ============================================================================

--- Create a raid frame for a unit
function FrameRenderer:CreateRaidFrame(unitToken, groupNum, posInGroup)
	if not UnitExists(unitToken) then
		return nil
	end
	
	local frameName = "InfinityHealer_" .. unitToken
	local frame = CreateFrame("Button", frameName, UIParent, "SecureActionButtonTemplate")
	
	-- Frame styling
	frame:SetSize(self.config.frameWidth, self.config.frameHeight)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 1,
		insets = {left = 1, right = 1, top = 1, bottom = 1}
	})
	frame:SetBackdropColor(0.08, 0.08, 0.08, 0.9)
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8)
	
	-- Name text
	local nameText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	nameText:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	nameText:SetText(UnitName(unitToken) or "Unknown")
	nameText:SetTextColor(1, 1, 1, 0.9)
	nameText:SetWidth(self.config.frameWidth - 4)
	nameText:SetJustifyH("LEFT")
	
	-- Role icon
	local roleIcon = frame:CreateTexture(nil, "OVERLAY")
	roleIcon:SetSize(12, 12)
	roleIcon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
	
	-- Health bar background
	local healthBG = CreateFrame("StatusBar", nil, frame)
	healthBG:SetSize(self.config.frameWidth - 4, 10)
	healthBG:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -15)
	healthBG:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	healthBG:SetStatusBarColor(0.15, 0.15, 0.15, 1)
	
	-- Health bar
	local healthBar = CreateFrame("StatusBar", nil, healthBG)
	healthBar:SetAllPoints(healthBG)
	healthBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	healthBar:SetStatusBarColor(self.config.colors.health.r, self.config.colors.health.g, self.config.colors.health.b, 0.8)
	
	-- Health text
	local healthText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalTiny")
	healthText:SetPoint("CENTER", healthBar, "CENTER")
	healthText:SetText("100%")
	healthText:SetTextColor(1, 1, 1, 0.8)
	healthText:SetJustifyH("CENTER")
	
	-- Mana bar
	local manaBar = CreateFrame("StatusBar", nil, frame)
	manaBar:SetSize(self.config.frameWidth - 4, 3)
	manaBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -27)
	manaBar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
	manaBar:SetStatusBarColor(self.config.colors.mana.r, self.config.colors.mana.g, self.config.colors.mana.b, 0.8)
	
	-- Store references
	frame.unitToken = unitToken
	frame.nameText = nameText
	frame.healthBar = healthBar
	frame.healthBG = healthBG
	frame.healthText = healthText
	frame.manaBar = manaBar
	frame.roleIcon = roleIcon
	frame.groupNum = groupNum or 1
	frame.posInGroup = posInGroup or 1
	frame.auras = {}
	
	-- Click-cast enabled
	frame:SetAttribute("type", "target")
	frame:SetAttribute("*type*", "target")
	
	-- Mouseover highlighting
	frame:SetScript("OnEnter", function(f)
		FrameRenderer:HighlightFrame(f)
	end)
	
	frame:SetScript("OnLeave", function(f)
		FrameRenderer:UnhighlightFrame(f)
	end)
	
	self.frames[unitToken] = frame
	return frame
end

--- Highlight a frame on mouseover
function FrameRenderer:HighlightFrame(frame)
	if not frame then return end
	
	frame:SetBackdropBorderColor(1, 1, 0, 1) -- Yellow border
	
	-- Set as focus target
	if frame.unitToken then
		SpellStopCasting()
	end
end

--- Unhighlight frame
function FrameRenderer:UnhighlightFrame(frame)
	if not frame then return end
	
	frame:SetBackdropBorderColor(0.3, 0.3, 0.3, 0.8) -- Normal border
end

-- ============================================================================
-- LAYOUT SYSTEM
-- ============================================================================

--- Layout frames in raid configuration (5 groups of 8 or 10 groups of 4)
function FrameRenderer:LayoutRaidFrames(groupSize)
	groupSize = groupSize or 40
	
	if not self.mainWindow then
		self.mainWindow = CreateFrame("Frame", "InfinityHealer_RaidWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		self.mainWindow:SetSize(400, 500)
		self.mainWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 50, -50)
		self.mainWindow:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 1,
		})
		self.mainWindow:SetBackdropColor(0, 0, 0, 0.5)
		self.mainWindow:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
	end
	
	-- Calculate group layout
	local numGroups = math.ceil(groupSize / 5)
	local framesPerCol = 8
	local colsPerRow = 5
	local colWidth = self.config.frameWidth + self.config.playerSpacing
	local groupHeight = (self.config.frameHeight + self.config.playerSpacing) * framesPerCol + self.config.groupSpacing
	
	-- Position all frames
	local frameIndex = 1
	local groupNum = 1
	local posInGroup = 1
	
	for i = 1, groupSize do
		local unitToken
		if groupSize <= 5 then
			unitToken = i == 1 and "player" or ("party" .. (i - 1))
		else
			unitToken = "raid" .. i
		end
		
		if UnitExists(unitToken) then
			-- Create frame if doesn't exist
			if not self.frames[unitToken] then
				self:CreateRaidFrame(unitToken, groupNum, posInGroup)
			end
			
			local frame = self.frames[unitToken]
			if frame then
				-- Calculate position in grid
				local col = (groupNum - 1) % colsPerRow
				local row = math.floor((groupNum - 1) / colsPerRow)
				local xOffset = col * (colWidth * framesPerCol + self.config.groupSpacing)
				local yOffset = row * groupHeight
				
				-- Position within group
				local groupCol = (posInGroup - 1) % framesPerCol
				local groupRow = math.floor((posInGroup - 1) / framesPerCol)
				
				frame:SetPoint("TOPLEFT", self.mainWindow, "TOPLEFT", 
					xOffset + groupCol * colWidth,
					-yOffset - groupRow * (self.config.frameHeight + self.config.playerSpacing))
				
				frame:Show()
				
				-- Register in group
				if not self.groups[groupNum] then
					self.groups[groupNum] = {}
				end
				table.insert(self.groups[groupNum], frame)
				
				posInGroup = posInGroup + 1
				
				-- Start new group every 5 members
				if posInGroup > 5 then
					groupNum = groupNum + 1
					posInGroup = 1
				end
			end
		end
		
		frameIndex = frameIndex + 1
	end
	
	self.mainWindow:Show()
	
	InfinityUtils:Info(string.format("Laid out %d raid frames in %d groups", groupSize, groupNum), "FrameRenderer")
end

--- Compact layout (single column, scrollable)
function FrameRenderer:LayoutCompactFrames(groupSize)
	groupSize = groupSize or 40
	
	if not self.mainWindow then
		self.mainWindow = CreateFrame("Frame", "InfinityHealer_CompactWindow", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		self.mainWindow:SetSize(120, 400)
		self.mainWindow:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
		self.mainWindow:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			tile = true, tileSize = 16, edgeSize = 1,
		})
		self.mainWindow:SetBackdropColor(0, 0, 0, 0.5)
		self.mainWindow:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
	end
	
	-- Simple vertical layout
	local yOffset = 0
	for i = 1, groupSize do
		local unitToken
		if groupSize <= 5 then
			unitToken = i == 1 and "player" or ("party" .. (i - 1))
		else
			unitToken = "raid" .. i
		end
		
		if UnitExists(unitToken) then
			if not self.frames[unitToken] then
				self:CreateRaidFrame(unitToken, 1, i)
			end
			
			local frame = self.frames[unitToken]
			if frame then
				frame:SetPoint("TOPLEFT", self.mainWindow, "TOPLEFT", 2, yOffset)
				frame:Show()
				yOffset = yOffset - (self.config.frameHeight + self.config.playerSpacing)
			end
		end
	end
	
	self.mainWindow:Show()
end

-- ============================================================================
-- HEALTH & STATUS UPDATES
-- ============================================================================

--- Update health bar for a unit
function FrameRenderer:UpdateUnitHealth(unitToken)
	local frame = self.frames[unitToken]
	if not frame then return end
	
	local health = UnitHealth(unitToken) or 100
	local maxHealth = UnitHealthMax(unitToken) or 100
	local healthPercent = (health / maxHealth) * 100
	
	-- Update health bar
	frame.healthBar:SetValue(healthPercent)
	
	-- Color based on health
	if healthPercent > 75 then
		frame.healthBar:SetStatusBarColor(0.2, 0.8, 0.2, 0.8) -- Green
	elseif healthPercent > 50 then
		frame.healthBar:SetStatusBarColor(1, 0.8, 0.2, 0.8) -- Yellow
	elseif healthPercent > 25 then
		frame.healthBar:SetStatusBarColor(1, 0.6, 0.2, 0.8) -- Orange
	else
		frame.healthBar:SetStatusBarColor(1, 0.2, 0.2, 0.8) -- Red
	end
	
	-- Update text
	local healthText = string.format("%.0f%%", healthPercent)
	if self.config.enableHealth then
		frame.healthText:SetText(healthText)
	end
end

--- Update mana bar for a unit
function FrameRenderer:UpdateUnitMana(unitToken)
	local frame = self.frames[unitToken]
	if not frame or not frame.manaBar then return end
	
	local mana = UnitMana(unitToken) or 0
	local maxMana = UnitMaxMana(unitToken) or 100
	local manaPercent = (mana / maxMana) * 100
	
	frame.manaBar:SetValue(manaPercent)
end

--- Update role icon
function FrameRenderer:UpdateUnitRole(unitToken)
	local frame = self.frames[unitToken]
	if not frame or not self.config.enableRoleIcons then return end
	
	local role = UnitGroupRolesAssigned(unitToken)
	if role == "TANK" then
		frame.roleIcon:SetTexture("Interface/LFGFrame/UI-LFG-ICON-ROLE")
		frame.roleIcon:SetTexCoord(0, 0.5, 0, 0.5) -- Warrior icon
	elseif role == "HEALER" then
		frame.roleIcon:SetTexture("Interface/LFGFrame/UI-LFG-ICON-ROLE")
		frame.roleIcon:SetTexCoord(0.5, 1, 0, 0.5) -- Healer icon
	elseif role == "DAMAGER" then
		frame.roleIcon:SetTexture("Interface/LFGFrame/UI-LFG-ICON-ROLE")
		frame.roleIcon:SetTexCoord(0, 0.5, 0.5, 1) -- DPS icon
	end
end

--- Update all visible frames
function FrameRenderer:UpdateAllFrames()
	local groupSize = GetNumGroupMembers()
	
	if groupSize == 0 then
		self:ClearFrames()
		return
	end
	
	-- Update each frame's health/mana
	for i = 1, groupSize do
		local unitToken
		if groupSize <= 5 then
			unitToken = i == 1 and "player" or ("party" .. (i - 1))
		else
			unitToken = "raid" .. i
		end
		
		if UnitExists(unitToken) then
			self:UpdateUnitHealth(unitToken)
			self:UpdateUnitMana(unitToken)
			self:UpdateUnitRole(unitToken)
		end
	end
end

-- ============================================================================
-- WINDOW MANAGEMENT
-- ============================================================================

--- Show all frames
function FrameRenderer:ShowFrames()
	if self.mainWindow then
		self.mainWindow:Show()
	end
	
	for unitToken, frame in pairs(self.frames) do
		frame:Show()
	end
end

--- Hide all frames
function FrameRenderer:HideFrames()
	if self.mainWindow then
		self.mainWindow:Hide()
	end
	
	for unitToken, frame in pairs(self.frames) do
		frame:Hide()
	end
end

--- Toggle frame visibility
function FrameRenderer:ToggleFrames()
	if self.mainWindow and self.mainWindow:IsShown() then
		self:HideFrames()
	else
		self:ShowFrames()
	end
end

--- Clear all frames
function FrameRenderer:ClearFrames()
	for unitToken, frame in pairs(self.frames) do
		frame:Hide()
	end
	
	self.frames = {}
	self.groups = {}
end

--- Set frame scale
function FrameRenderer:SetFrameScale(scale)
	if self.mainWindow then
		self.mainWindow:SetScale(scale)
	end
end

--- Set frame position
function FrameRenderer:SetFramePosition(x, y)
	if self.mainWindow then
		self.mainWindow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
	end
end

-- ============================================================================
-- INITIALIZATION & UPDATE LOOP
-- ============================================================================

function FrameRenderer:Initialize()
	InfinityUtils:Info("FrameRenderer initializing...", "FrameRenderer")
	
	-- Create update frame
	local updateFrame = CreateFrame("Frame")
	local healthElapsed = 0
	local statusElapsed = 0
	
	updateFrame:SetScript("OnUpdate", function(f, delta)
		if GetNumGroupMembers() == 0 then
			return
		end
		
		-- Health updates (slower)
		healthElapsed = healthElapsed + delta
		if healthElapsed >= self.config.healthUpdateRate then
			self:UpdateAllFrames()
			healthElapsed = 0
		end
		
		-- Status updates (faster)
		statusElapsed = statusElapsed + delta
		if statusElapsed >= self.config.statusUpdateRate then
			-- Could add debuff/buff updates here
			statusElapsed = 0
		end
	end)
	
	-- Register for group updates
	local groupUpdateFrame = CreateFrame("Frame")
	groupUpdateFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
	groupUpdateFrame:RegisterEvent("RAID_ROSTER_UPDATE")
	groupUpdateFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
	
	groupUpdateFrame:SetScript("OnEvent", function(f, event)
		local groupSize = GetNumGroupMembers()
		
		if groupSize > 0 then
			-- Determine best layout
			if groupSize <= 5 then
				self.config.layoutMode = "party"
				self:LayoutCompactFrames(groupSize)
			elseif groupSize <= 20 then
				self.config.layoutMode = "group"
				self:LayoutCompactFrames(groupSize)
			else
				self.config.layoutMode = "raid"
				self:LayoutRaidFrames(groupSize)
			end
		else
			self:ClearFrames()
		end
	end)
	
	InfinityUtils:Info("FrameRenderer initialized", "FrameRenderer")
end

-- ============================================================================
-- SLASH COMMANDS
-- ============================================================================

if InfinityCommandRegistry then
	InfinityCommandRegistry:RegisterCommand("frames", function(args)
		if not args or #args == 0 then
			FrameRenderer:ToggleFrames()
		elseif args[1] == "show" then
			FrameRenderer:ShowFrames()
		elseif args[1] == "hide" then
			FrameRenderer:HideFrames()
		elseif args[1] == "scale" and args[2] then
			FrameRenderer:SetFrameScale(tonumber(args[2]) or 1)
		elseif args[1] == "pos" and args[2] and args[3] then
			FrameRenderer:SetFramePosition(tonumber(args[2]) or 50, tonumber(args[3]) or -50)
		end
	end, {"frame", "healer"})
end

print("[INFO] Frame Renderer module loaded successfully")
