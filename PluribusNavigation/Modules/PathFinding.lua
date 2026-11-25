-- Terrain-, Road-, & Obstacle-Aware Path Finding Integration
-- Routes all waypoint and direction requests through PluribusHivePathfinder + PluribusHiveTerrainMesh
-- (roads, mountain passes, bridges, learned walkable navmesh, game-internal MapLinks/AreaPOIs, and barrier avoidance).
local PluribusPathFinding = {}
_G.PluribusPathFinding = PluribusPathFinding

PluribusPathFinding.shortestPathAvailable = _G.SPF ~= nil
PluribusPathFinding.tomtomAvailable = _G.TomTom ~= nil

function PluribusPathFinding:Initialize()
	self.shortestPathAvailable = _G.SPF ~= nil
	self.tomtomAvailable = _G.TomTom ~= nil
	PluribusUtils:Info("Path finding initialized (TerrainNavMesh + Roads active).", "Navigation")
end

local function NormalizePct(val)
	local n = tonumber(val) or 50
	if n > 0 and n <= 1.0 then return n * 100 end
	return n
end

function PluribusPathFinding:CalculatePath(startX, startY, startZone, endX, endY, endZone, destName)
	local sZone = startZone or (GetRealZoneText and GetRealZoneText()) or "Elwynn Forest"
	local eZone = endZone or sZone
	local sx, sy = NormalizePct(startX), NormalizePct(startY)
	local ex, ey = NormalizePct(endX), NormalizePct(endY)

	-- Primary: PluribusHivePathfinder + TerrainMesh (roads, passes, barriers, internal map waypoints, navmesh)
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.ComputeRoute then
		local route = _G.PluribusHivePathfinder:ComputeRoute(sZone, sx, sy, eZone, ex, ey, { destName = destName or eZone })
		if route and route.legs and #route.legs > 0 then
			return route.legs, route
		end
	end

	-- Optional external ShortestPathFinder fallback if present
	if self.shortestPathAvailable and SPF and SPF.Path then
		local path = SPF.Path(sZone, sx, sy, eZone, ex, ey)
		if path then
			return path
		end
	end

	return { { x = ex, y = ey, zone = eZone, label = destName or eZone, mode = "road" } }
end

function PluribusPathFinding:GetDirectionTo(targetX, targetY, currentX, currentY, targetZone)
	local curZone = (GetRealZoneText and GetRealZoneText()) or targetZone or "Elwynn Forest"
	if not currentX or not currentY then
		currentX, currentY = PluribusUtils:GetUnitMapPosition("player")
	end
	if not currentX or not currentY then
		return nil
	end

	local cx = NormalizePct(currentX)
	local cy = NormalizePct(currentY)
	local tx = NormalizePct(targetX)
	local ty = NormalizePct(targetY)

	-- Follow active terrain/road leg instead of aiming straight through walls or mountains!
	local activeLeg = nil
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.GetActiveLeg then
		activeLeg = _G.PluribusHivePathfinder:GetActiveLeg(curZone, cx, cy)
		if activeLeg and activeLeg.x and activeLeg.y then
			tx, ty = activeLeg.x, activeLeg.y
		end
	end

	local dx = tx - cx
	local dy = ty - cy
	local angle = math.atan2(-dx, -dy)
	local distYards = (_G.PluribusHivePathfinder and _G.PluribusHivePathfinder.DistanceYards)
		and _G.PluribusHivePathfinder:DistanceYards(curZone, cx, cy, tx, ty)
		or (math.sqrt(dx * dx + dy * dy) * 28)

	return {
		angle = angle,
		distance = distYards,
		dx = dx,
		dy = dy,
		leg = activeLeg,
		targetX = tx,
		targetY = ty,
	}
end

function PluribusPathFinding:SetWaypoint(x, y, zone, description)
	local nx, ny = NormalizePct(x), NormalizePct(y)
	local destZone = zone or (GetRealZoneText and GetRealZoneText()) or "Elwynn Forest"
	local label = description or destZone

	-- Route through PluribusNavigationUI + HivePathfinder so multi-leg road/mesh routing & native SuperTrack activate!
	if _G.PluribusNavigationUI and _G.PluribusNavigationUI.SetWaypoint then
		_G.PluribusNavigationUI:SetWaypoint(label, destZone, nx, ny)
		return true
	end

	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.SetRouteTo then
		_G.PluribusHivePathfinder:SetRouteTo(label, destZone, nx, ny)
	end

	if self.tomtomAvailable and _G.TomTom and _G.TomTom.AddWaypoint then
		pcall(_G.TomTom.AddWaypoint, _G.TomTom, destZone, nx, ny, label)
	end
	if _G.PluribusScreenArrow and _G.PluribusScreenArrow.SetTarget then
		_G.PluribusScreenArrow:SetTarget(nx, ny, 0, label)
	end
	if _G.PluribusMinimapArrow and _G.PluribusMinimapArrow.SetTarget then
		_G.PluribusMinimapArrow:SetTarget(nx, ny, 0)
	end
	return true
end

return PluribusPathFinding
