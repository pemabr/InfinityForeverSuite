-- On-Screen Arrow with Distance Indicator
-- Shows directional arrow and distance to current objective

local ScreenArrow = {
	frame = nil,
	targetX = nil,
	targetY = nil,
	targetZ = nil,
	updateInterval = 0.3,
	lastUpdate = 0,
	enabled = true,
	maxDistance = 100, -- Max distance to show arrow (in yards)
}

_G.PluribusScreenArrow = ScreenArrow

-- Initialize screen arrow
function ScreenArrow:Initialize()
	if self.frame then
		return
	end
	
	-- Create main frame
	local frame = CreateFrame("Frame", "PluribusScreenArrow", UIParent)
	frame:SetSize(200, 100)
	frame:SetPoint("TOP", UIParent, "TOP", 0, -30)
	
	-- Background
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints(frame)
	bg:SetColorTexture(0, 0, 0, 0.3)
	frame.bg = bg
	
	-- Arrow icon
	local arrow = frame:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(64, 64)
	arrow:SetPoint("CENTER", frame, "TOP", 0, -20)
	arrow:SetTexture("Interface/Minimap/Arrow")
	frame.arrow = arrow
	
	-- Distance text
	local distance = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	distance:SetPoint("CENTER", frame, "TOP", 0, -60)
	distance:SetJustifyH("CENTER")
	frame.distance = distance
	
	-- Objective text
	local objective = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	objective:SetPoint("CENTER", frame, "TOP", 0, -5)
	objective:SetJustifyH("CENTER")
	objective:SetWidth(190)
	objective:SetHeight(25)
	frame.objective = objective
	
	-- Direction text (N, NE, E, etc.)
	local direction = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	direction:SetPoint("CENTER", frame, "BOTTOM", 0, 5)
	direction:SetJustifyH("CENTER")
	frame.direction = direction
	
	frame:Hide()
	self.frame = frame
	self:RegisterUpdateLoop()
	
	PluribusUtils:Info("Screen arrow initialized", "Navigation")
end

-- Register update loop
function ScreenArrow:RegisterUpdateLoop()
	local updateFrame = CreateFrame("Frame")
	updateFrame:SetScript("OnUpdate", function(self, elapsed)
		ScreenArrow:OnUpdate(elapsed)
	end)
end

-- Main update loop
function ScreenArrow:OnUpdate(elapsed)
	if not self.enabled or not self.frame or not self.targetX then
		self.frame:Hide()
		return
	end
	
	self.lastUpdate = self.lastUpdate + elapsed
	
	if self.lastUpdate < self.updateInterval then
		return
	end
	
	self.lastUpdate = 0
	
	-- Get player position (0..1 -> 0..100%)
	local rawX, rawY = PluribusUtils:GetUnitMapPosition("player")
	if not rawX or not rawY or (rawX == 0 and rawY == 0) then
		self.frame:Hide()
		return
	end
	local px, py = rawX * 100, rawY * 100
	local tx = (self.targetX <= 1.0) and (self.targetX * 100) or self.targetX
	local ty = (self.targetY <= 1.0) and (self.targetY * 100) or self.targetY

	-- Follow active road/terrain-mesh leg waypoint instead of straight line through obstacles!
	local curZone = (GetRealZoneText and GetRealZoneText()) or ""
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.GetActiveLeg then
		local leg = _G.PluribusHivePathfinder:GetActiveLeg(curZone, px, py)
		if leg and leg.x and leg.y then
			tx, ty = leg.x, leg.y
		end
	end

	local dx = tx - px
	local dy = ty - py
	local facing = (GetPlayerFacing and GetPlayerFacing()) or 0
	local targetAngle = math.atan2(-dx, -dy)
	local relAngle = targetAngle - facing

	if self.frame.arrow.SetRotation then
		pcall(self.frame.arrow.SetRotation, self.frame.arrow, relAngle)
	end

	local distance = (_G.PluribusHivePathfinder and _G.PluribusHivePathfinder.DistanceYards)
		and _G.PluribusHivePathfinder:DistanceYards(curZone, px, py, tx, ty)
		or (math.sqrt(dx * dx + dy * dy) * 28)

	if distance < 1760 then
		self.frame.distance:SetText(string.format("%.0f yards", distance))
	else
		self.frame.distance:SetText(string.format("%.1f miles", distance / 1760))
	end

	local directionName = self:GetDirectionName(targetAngle)
	self.frame.direction:SetText(directionName)

	if self.maxDistance and self.maxDistance > 0 and distance > self.maxDistance and not (_G.PluribusHivePathfinder and _G.PluribusHivePathfinder.activeRoute) then
		self.frame:Hide()
	else
		self.frame:Show()
	end
end

-- Get compass direction name from angle
function ScreenArrow:GetDirectionName(angle)
	-- Convert radians to degrees (0 = up/north)
	local degrees = math.deg(angle)
	degrees = degrees % 360
	
	if degrees < 22.5 or degrees >= 337.5 then
		return "NORTH"
	elseif degrees < 67.5 then
		return "NORTHEAST"
	elseif degrees < 112.5 then
		return "EAST"
	elseif degrees < 157.5 then
		return "SOUTHEAST"
	elseif degrees < 202.5 then
		return "SOUTH"
	elseif degrees < 247.5 then
		return "SOUTHWEST"
	elseif degrees < 292.5 then
		return "WEST"
	else
		return "NORTHWEST"
	end
end

-- Set target position
function ScreenArrow:SetTarget(x, y, z, objectiveText)
	self.targetX = x
	self.targetY = y
	self.targetZ = z or 0
	
	if objectiveText and self.frame then
		self.frame.objective:SetText(objectiveText)
	end
	
	if self.frame then
		self.frame:Show()
	end
end

-- Clear target
function ScreenArrow:ClearTarget()
	self.targetX = nil
	self.targetY = nil
	self.targetZ = nil
	
	if self.frame then
		self.frame.objective:SetText("")
		self.frame:Hide()
	end
end

-- Set target objective text
function ScreenArrow:SetObjectiveText(text)
	if self.frame then
		self.frame.objective:SetText(text)
	end
end

-- Get target position
function ScreenArrow:GetTarget()
	return self.targetX, self.targetY, self.targetZ
end

-- Get distance to target
function ScreenArrow:GetDistance()
	if not self.targetX then
		return 0
	end
	
	local playerX, playerY = PluribusUtils:GetUnitMapPosition("player")
	if not playerX or not playerY or (playerX == 0 and playerY == 0) then
		return 0
	end
	
	local dx = self.targetX - playerX
	local dy = self.targetY - playerY
	
	return math.sqrt(dx * dx + dy * dy) * 100 -- Convert to yards
end

-- Set arrow visibility
function ScreenArrow:SetEnabled(enabled)
	self.enabled = enabled
	if self.frame then
		if enabled then
			if self.targetX then
				self.frame:Show()
			end
		else
			self.frame:Hide()
		end
	end
end

-- Set arrow position on screen
function ScreenArrow:SetScreenPosition(x, y)
	if self.frame then
		self.frame:ClearAllPoints()
		self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y)
	end
end

-- Set arrow color
function ScreenArrow:SetArrowColor(r, g, b, a)
	if self.frame and self.frame.arrow then
		self.frame.arrow:SetColorTexture(r, g, b, a or 1)
	end
end

-- Set max distance for arrow visibility
function ScreenArrow:SetMaxDistance(maxDistance)
	self.maxDistance = maxDistance
end

return ScreenArrow
