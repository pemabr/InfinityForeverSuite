-- Path Finding Integration
local InfinityPathFinding = {}
_G.InfinityPathFinding = InfinityPathFinding

InfinityPathFinding.shortestPathAvailable = _G.SPF ~= nil
InfinityPathFinding.tomtomAvailable = _G.TomTom ~= nil

function InfinityPathFinding:Initialize()
	self.shortestPathAvailable = _G.SPF ~= nil
	self.tomtomAvailable = _G.TomTom ~= nil
	InfinityUtils:Info("Path finding initialized. SPF: " .. tostring(self.shortestPathAvailable) .. ", TomTom: " .. tostring(self.tomtomAvailable), "Navigation")
end

function InfinityPathFinding:CalculatePath(startX, startY, startZone, endX, endY, endZone)
	-- Try shortest path first
	if self.shortestPathAvailable and SPF and SPF.Path then
		local path = SPF.Path(startZone, startX, startY, endZone, endX, endY)
		if path then
			return path
		end
	end
	
	-- Fallback to simple waypoint
	return {{x = endX, y = endY, zone = endZone}}
end

function InfinityPathFinding:GetDirectionTo(targetX, targetY, currentX, currentY)
	if not currentX or not currentY then
		currentX, currentY = InfinityUtils:GetUnitMapPosition("player")
	end
	
	if not currentX or not currentY then
		return nil
	end
	
	local dx = targetX - currentX
	local dy = targetY - currentY
	local angle = math.atan2(dy, dx)
	
	return {
		angle = angle,
		distance = math.sqrt(dx * dx + dy * dy),
		dx = dx,
		dy = dy,
	}
end

function InfinityPathFinding:SetWaypoint(x, y, zone, description)
	if self.tomtomAvailable and _G.TomTom and _G.TomTom.AddWaypoint then
		_G.TomTom:AddWaypoint(zone, x, y, description)
		return true
	end
	-- Standalone fallback using built-in Infinity arrows
	if _G.InfinityScreenArrow and _G.InfinityScreenArrow.SetTarget then
		_G.InfinityScreenArrow:SetTarget(x, y, 0, description or "Waypoint")
	end
	if _G.InfinityMinimapArrow and _G.InfinityMinimapArrow.SetTarget then
		_G.InfinityMinimapArrow:SetTarget(x, y, 0)
	end
	return true
end

return InfinityPathFinding
