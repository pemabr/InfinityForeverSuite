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
	
	-- Get player position (0..1 -> 0..100%)
	local rawX, rawY = PluribusUtils:GetUnitMapPosition("player")
	if not rawX or not rawY or (rawX == 0 and rawY == 0) then
		return
	end
	local px, py = rawX * 100, rawY * 100
	local tx = (self.targetX <= 1.0) and (self.targetX * 100) or self.targetX
	local ty = (self.targetY <= 1.0) and (self.targetY * 100) or self.targetY

	-- Follow active road/terrain-mesh leg waypoint instead of straight line!
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
	local angle = math.atan2(-dx, -dy) - facing

	if self.arrow.texture.SetRotation then
		pcall(self.arrow.texture.SetRotation, self.arrow.texture, angle)
	end

	local distance = (_G.PluribusHivePathfinder and _G.PluribusHivePathfinder.DistanceYards)
		and _G.PluribusHivePathfinder:DistanceYards(curZone, px, py, tx, ty)
		or (math.sqrt(dx * dx + dy * dy) * 28)
	self.arrow.distance:SetText(string.format("%.0f yards", distance))

	if distance < 5 then
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
