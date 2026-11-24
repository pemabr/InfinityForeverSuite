-- Minimap Arrow Display
-- Shows directional arrow to current objective on minimap

local MinimapArrow = {
	arrow = nil,
	targetX = nil,
	targetY = nil,
	targetZ = nil,
	updateInterval = 0.5,
	lastUpdate = 0,
	enabled = true,
	followsObjective = true,
}

_G.PluribusMinimapArrow = MinimapArrow

-- Create minimap arrow
function MinimapArrow:Initialize()
	if self.arrow then
		return
	end
	
	-- Create arrow frame
	local arrow = CreateFrame("Frame", "PluribusMinimapArrow", Minimap)
	arrow:SetSize(32, 32)
	arrow:SetPoint("CENTER", Minimap, "CENTER")
	
	-- Create arrow texture
	local texture = arrow:CreateTexture(nil, "OVERLAY")
	texture:SetAllPoints(arrow)
	texture:SetTexture("Interface/Minimap/Arrow")
	texture:SetTexCoord(0, 1, 0, 1)
	arrow.texture = texture
	
	-- Distance text
	local distance = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	distance:SetPoint("BOTTOM", arrow, "BOTTOM", 0, -15)
	distance:SetJustifyH("CENTER")
	arrow.distance = distance
	
	self.arrow = arrow
	self:RegisterUpdateLoop()
	
	PluribusUtils:Info("Minimap arrow initialized", "Navigation")
end

-- Register update loop
function MinimapArrow:RegisterUpdateLoop()
	local frame = CreateFrame("Frame")
	frame:SetScript("OnUpdate", function(self, elapsed)
		MinimapArrow:OnUpdate(elapsed)
	end)
end

-- Update arrow position and rotation
function MinimapArrow:OnUpdate(elapsed)
	if not self.enabled or not self.arrow or not self.targetX then
		return
	end
	
	self.lastUpdate = self.lastUpdate + elapsed
	
	if self.lastUpdate < self.updateInterval then
		return
	end
	
	self.lastUpdate = 0
	
	-- Get player position
	local playerX, playerY = PluribusUtils:GetUnitMapPosition("player")
	
	if not playerX or not playerY or (playerX == 0 and playerY == 0) then
		return
	end
	
	-- Calculate direction to target
	local dx = self.targetX - playerX
	local dy = self.targetY - playerY
	
	-- Calculate angle (0 = up, 90 = right, 180 = down, 270 = left)
	local angle = math.atan2(dy, dx)
	angle = angle - math.pi / 2 -- Rotate so 0 is up
	
	-- Apply rotation to arrow
	self.arrow.texture:SetRotation(angle)
	
	-- Calculate distance
	local distance = math.sqrt(dx * dx + dy * dy) * 100
	local distanceText = string.format("%.0f yards", distance)
	self.arrow.distance:SetText(distanceText)
	
	-- Update arrow visibility
	if distance < 0.1 then
		self.arrow:Hide()
	else
		self.arrow:Show()
	end
end

-- Set target position
function MinimapArrow:SetTarget(x, y, z)
	self.targetX = x
	self.targetY = y
	self.targetZ = z or 0
	
	if self.arrow then
		self.arrow:Show()
	end
end

-- Clear target
function MinimapArrow:ClearTarget()
	self.targetX = nil
	self.targetY = nil
	self.targetZ = nil
	
	if self.arrow then
		self.arrow:Hide()
	end
end

-- Set arrow color
function MinimapArrow:SetColor(r, g, b, a)
	if self.arrow and self.arrow.texture then
		self.arrow.texture:SetColorTexture(r, g, b, a or 1)
	end
end

-- Toggle arrow visibility
function MinimapArrow:SetEnabled(enabled)
	self.enabled = enabled
	if self.arrow then
		if enabled then
			self.arrow:Show()
		else
			self.arrow:Hide()
		end
	end
end

-- Get target position
function MinimapArrow:GetTarget()
	return self.targetX, self.targetY, self.targetZ
end

-- Distance to target
function MinimapArrow:GetDistance()
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

return MinimapArrow
