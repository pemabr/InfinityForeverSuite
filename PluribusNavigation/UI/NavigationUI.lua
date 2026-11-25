-- PluribusNavigation UI, Smart Multi-Modal Pathfinder Compass & Persistent World Map Pins
-- 1. Turn-by-turn Compass Arrow HUD powered by PluribusHivePathfinder (points along shortest-time roads,
--    passes, water/Aquatic-Form shortcuts, discovered Flight Paths, and guild-synced Boats/Zeppelins,
--    while avoiding high-level zones & mobs above the player's level!)
-- 2. Persistent World Map Pins & Instant Alt-Click Nav:
--    Alt+Left-Click on World Map navigates immediately; Ctrl+Left-Click places a persistent Pin & navigates!
-- 3. Auto-updating Dynamic Quest & To-Do Route with temporary Stop Skipping, categorized Azeroth destinations,
--    Map Pins manager, live Guildmate GPS, and /way support.

local PluribusNavigationUI = {
	mainWindow = nil,
	hudFrame = nil,
	activeWaypoint = nil,
	selectedCat = "Route",
	worldMapAttached = false,
	worldMapPinButtons = {},
	worldMapRouteLayer = nil,
	worldMapRouteLines = {},
	worldMapRouteDots = {},
	worldMapRoutePins = {},
	worldMapDynStopPins = {},
	minimapRouteLayer = nil,
	minimapRouteDots = {},
	minimapEdgePip = nil,
	_lastMapClickAt = 0,
}
_G.PluribusNavigationUI = PluribusNavigationUI

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

PluribusNavigationUI.DESTINATIONS = {
	Raids = {
		{ name = "Naxxramas", zone = "Eastern Plaguelands", x = 39.2, y = 26.4, icon = "Interface\\Icons\\Spell_Shadow_RaiseDead" },
		{ name = "Blackrock Mountain (MC / BWL)", zone = "Burning Steppes", x = 29.4, y = 38.2, icon = "Interface\\Icons\\Spell_Fire_LavaSpawn" },
		{ name = "Gates of Ahn'Qiraj (AQ20 / AQ40)", zone = "Silithus", x = 28.6, y = 92.4, icon = "Interface\\Icons\\INV_Misc_QirajiCrystal_05" },
		{ name = "Onyxia's Lair", zone = "Dustwallow Marsh", x = 52.2, y = 76.1, icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
		{ name = "Zul'Gurub", zone = "Stranglethorn Vale", x = 53.8, y = 17.6, icon = "Interface\\Icons\\INV_Bijou_Green" },
	},
	Dungeons = {
		{ name = "Stratholme (Main / Service)", zone = "Eastern Plaguelands", x = 31.2, y = 14.0, icon = "Interface\\Icons\\INV_Misc_Bone_Skull_01" },
		{ name = "Scholomance", zone = "Western Plaguelands", x = 69.4, y = 73.1, icon = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
		{ name = "Dire Maul", zone = "Feralas", x = 59.1, y = 44.3, icon = "Interface\\Icons\\INV_Misc_Key_14" },
		{ name = "Blackrock Depths / UBRS", zone = "Searing Gorge", x = 35.1, y = 84.9, icon = "Interface\\Icons\\INV_Hammer_04" },
		{ name = "Scarlet Monastery", zone = "Tirisfal Glades", x = 85.2, y = 32.5, icon = "Interface\\Icons\\INV_Shield_10" },
	},
	Cities = {
		{ name = "Stormwind City", zone = "Elwynn Forest", x = 32.0, y = 49.5, icon = "Interface\\Icons\\INV_BannerPVP_02" },
		{ name = "Ironforge", zone = "Dun Morogh", x = 53.3, y = 34.8, icon = "Interface\\Icons\\Trade_BlackSmithing" },
		{ name = "Orgrimmar", zone = "Durotar", x = 45.8, y = 12.6, icon = "Interface\\Icons\\INV_BannerPVP_01" },
		{ name = "Undercity", zone = "Tirisfal Glades", x = 61.8, y = 65.2, icon = "Interface\\Icons\\Spell_Shadow_Charm" },
		{ name = "Booty Bay", zone = "Stranglethorn Vale", x = 27.4, y = 77.2, icon = "Interface\\Icons\\INV_Misc_Coin_01" },
		{ name = "Gadgetzan", zone = "Tanaris", x = 52.3, y = 27.6, icon = "Interface\\Icons\\Trade_Engineering" },
	},
	Bosses = {
		{ name = "Azuregos Spawn", zone = "Azshara", x = 56.1, y = 80.5, icon = "Interface\\Icons\\Spell_Frost_FrostBolt02" },
		{ name = "Lord Kazzak", zone = "Blasted Lands", x = 32.4, y = 48.2, icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
		{ name = "Emeriss / Dragons (Duskwood)", zone = "Duskwood", x = 46.8, y = 37.5, icon = "Interface\\Icons\\Spell_Nature_AbolishMagic" },
		{ name = "Dragons of Nightmare (Ashenvale)", zone = "Ashenvale", x = 93.7, y = 35.6, icon = "Interface\\Icons\\Spell_Nature_AbolishMagic" },
	},
}

-- ============================================================================
-- PERSISTENT WORLD MAP PINS (Set, Delete, Navigate, Render on WorldMapFrame)
-- ============================================================================
function PluribusNavigationUI:GetPinsDB()
	if _G.PluribusHive and _G.PluribusHive.GetDB then
		local db = _G.PluribusHive:GetDB()
		db.mapPins = db.mapPins or {}
		return db.mapPins
	end
	self._fallbackPins = self._fallbackPins or {}
	return self._fallbackPins
end

function PluribusNavigationUI:AddPin(name, zone, x, y, mapID)
	local pins = self:GetPinsDB()
	local nx = math.floor(math.max(0, math.min(100, tonumber(x) or 50)) * 10 + 0.5) / 10
	local ny = math.floor(math.max(0, math.min(100, tonumber(y) or 50)) * 10 + 0.5) / 10
	local pinZone = tostring(zone or (GetRealZoneText and GetRealZoneText()) or "Azeroth")
	local pinName = (name and name ~= "") and tostring(name) or (pinZone .. string.format(" (%.1f, %.1f)", nx, ny))
	local pin = {
		id = "pin_" .. tostring(time()) .. "_" .. tostring(math.random(100, 999)),
		name = pinName,
		zone = pinZone,
		x = nx,
		y = ny,
		mapID = tonumber(mapID) or 0,
		createdAt = time(),
	}
	table.insert(pins, 1, pin)
	while #pins > 50 do table.remove(pins) end

	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification("|cff4ade80" .. L("NAV_PIN_ADDED", pin.name, pin.x, pin.y) .. "|r", 3)
	end
	self:RefreshWorldMapPins()
	return pin
end

function PluribusNavigationUI:DeletePin(pinId)
	local pins = self:GetPinsDB()
	for i, p in ipairs(pins) do
		if p.id == pinId then
			local removedName = p.name
			table.remove(pins, i)
			if _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification("|cfffbbf24" .. L("NAV_PIN_REMOVED", removedName or "Pin") .. "|r", 2.5)
			end
			self:RefreshWorldMapPins()
			return true
		end
	end
	return false
end

function PluribusNavigationUI:ClearAllPins()
	local pins = self:GetPinsDB()
	for i = #pins, 1, -1 do
		table.remove(pins, i)
	end
	self:RefreshWorldMapPins()
end

function PluribusNavigationUI:GetCurrentViewedMapContext()
	local zoneName = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local mapID = 0
	if _G.WorldMapFrame and _G.WorldMapFrame.GetMapID then
		local ok, mid = pcall(_G.WorldMapFrame.GetMapID, _G.WorldMapFrame)
		if ok and mid and mid > 0 then
			mapID = mid
			if C_Map and C_Map.GetMapInfo then
				local okI, info = pcall(C_Map.GetMapInfo, mid)
				if okI and info and info.name then
					zoneName = info.name
				end
			end
		end
	elseif GetMapInfo then
		local ok, mName = pcall(GetMapInfo)
		if ok and mName and mName ~= "" then
			zoneName = mName
		end
	end
	return zoneName, mapID
end

function PluribusNavigationUI:GetWorldMapCanvas()
	if _G.WorldMapFrame and _G.WorldMapFrame.ScrollContainer and _G.WorldMapFrame.ScrollContainer.Child then
		return _G.WorldMapFrame.ScrollContainer.Child
	end
	return _G.WorldMapButton or _G.WorldMapDetailFrame or _G.WorldMapFrame
end

function PluribusNavigationUI:RefreshWorldMapPins()
	for _, btn in ipairs(self.worldMapPinButtons) do
		btn:Hide()
	end
	if not _G.WorldMapFrame or not _G.WorldMapFrame:IsShown() then return end

	local canvas = self:GetWorldMapCanvas()
	if not canvas then return end
	local cw = canvas:GetWidth() or 0
	local ch = canvas:GetHeight() or 0
	if cw <= 10 or ch <= 10 then return end

	local viewedZone, viewedMapID = self:GetCurrentViewedMapContext()
	local pins = self:GetPinsDB()
	local poolIdx = 0

	for _, pin in ipairs(pins) do
		local matchMap = (viewedMapID > 0 and pin.mapID == viewedMapID)
			or (pin.zone and viewedZone and pin.zone:lower() == viewedZone:lower())
		if matchMap then
			poolIdx = poolIdx + 1
			local btn = self.worldMapPinButtons[poolIdx]
			if not btn then
				btn = CreateFrame("Button", "PluribusWorldMapPin" .. poolIdx, canvas)
				btn:SetSize(20, 20)
				btn:SetFrameStrata("HIGH")
				btn:SetFrameLevel((canvas:GetFrameLevel() or 5) + 20)
				btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

				local tex = btn:CreateTexture(nil, "OVERLAY")
				tex:SetAllPoints()
				tex:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\CompassArrow")
				tex:SetVertexColor(0.22, 0.85, 1.0, 1.0)
				btn.tex = tex

				local ring = btn:CreateTexture(nil, "BACKGROUND")
				ring:SetSize(24, 24)
				ring:SetPoint("CENTER")
				ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
				ring:SetVertexColor(0.95, 0.75, 0.20, 0.95)

				self.worldMapPinButtons[poolIdx] = btn
			end

			btn:SetParent(canvas)
			btn:ClearAllPoints()
			local px = (pin.x / 100) * cw
			local py = -(pin.y / 100) * ch
			btn:SetPoint("CENTER", canvas, "TOPLEFT", px, py)

			btn:SetScript("OnClick", function(_, mouseBtn)
				if mouseBtn == "RightButton" then
					PluribusNavigationUI:DeletePin(pin.id)
				else
					PluribusNavigationUI:SetWaypoint(pin.name, pin.zone, pin.x, pin.y, pin.mapID)
				end
			end)
			btn:SetScript("OnEnter", function(selfBtn)
				GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
				GameTooltip:SetText("|cff38bdf8" .. pin.name .. "|r")
				GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", pin.zone, pin.x, pin.y), 0.85, 0.92, 1.0)
				GameTooltip:AddLine("Linksklick / Left-Click: " .. L("TODO_NAV_ROUTE"), 0.29, 0.87, 0.50)
				GameTooltip:AddLine("Rechtsklick / Right-Click: " .. L("DELETE"), 0.97, 0.44, 0.44)
				GameTooltip:Show()
			end)
			btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
			btn:Show()
		end
	end

	self:RefreshWorldMapRoutePath()
end

-- Mode colors shared by World Map path, Minimap path, and Compass HUD
local ROUTE_MODE_COLORS = {
	road     = { 0.29, 0.87, 0.50 },
	water    = { 0.13, 0.83, 0.93 },
	flight   = { 0.22, 0.74, 0.97 },
	boat     = { 0.98, 0.78, 0.24 },
	zeppelin = { 0.98, 0.78, 0.24 },
	portal   = { 0.38, 0.72, 1.00 },
	summon   = { 0.75, 0.45, 0.98 },
}

local function GetRouteModeColor(mode)
	local m = tostring(mode or "road"):lower()
	return ROUTE_MODE_COLORS[m] or ROUTE_MODE_COLORS.road
end

-- ============================================================================
-- WORLD MAP ROUTE PATH OVERLAY (Lines + Breadcrumb Trail + Interactive Leg Pins)
-- ============================================================================
function PluribusNavigationUI:HideWorldMapRoutePath()
	for _, ln in ipairs(self.worldMapRouteLines) do
		if ln and ln.Hide then ln:Hide() end
	end
	for _, dt in ipairs(self.worldMapRouteDots) do
		if dt and dt.Hide then dt:Hide() end
	end
	for _, pin in ipairs(self.worldMapRoutePins) do
		if pin and pin.Hide then pin:Hide() end
	end
	for _, dp in ipairs(self.worldMapDynStopPins) do
		if dp and dp.Hide then dp:Hide() end
	end
end

function PluribusNavigationUI:RefreshWorldMapDynamicStops(canvas, cw, ch, viewedZone)
	if not _G.PluribusHiveDynamicRoute or not _G.PluribusHiveDynamicRoute.GetActiveAndSkipped then return end
	local activeStops = _G.PluribusHiveDynamicRoute:GetActiveAndSkipped()
	if not activeStops or #activeStops == 0 then return end

	local pf = _G.PluribusHivePathfinder
	local vz = (pf and pf.CanonicalZone and pf:CanonicalZone(viewedZone)) or viewedZone
	local activeWpStopId = self.activeWaypoint and self.activeWaypoint._stopId
	local poolIdx = 0

	for stopIdx, stop in ipairs(activeStops) do
		if stop.id ~= activeWpStopId then
			local sz = (pf and pf.CanonicalZone and pf:CanonicalZone(stop.zone)) or stop.zone
			if sz and vz and sz:lower() == vz:lower() and stop.x and stop.y then
				poolIdx = poolIdx + 1
				if poolIdx > 24 then break end
				local btn = self.worldMapDynStopPins[poolIdx]
				if not btn then
					btn = CreateFrame("Button", "PluribusWorldMapDynStop" .. poolIdx, canvas)
					btn:SetSize(18, 18)
					btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
					local bg = btn:CreateTexture(nil, "BACKGROUND")
					bg:SetAllPoints()
					bg:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
					btn.bg = bg
					local core = btn:CreateTexture(nil, "ARTWORK")
					core:SetSize(11, 11)
					core:SetPoint("CENTER")
					btn.core = core
					local lbl = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
					lbl:SetPoint("CENTER")
					btn.lbl = lbl
					self.worldMapDynStopPins[poolIdx] = btn
				end
				local col = (stop.kind == "todo") and { 0.22, 0.74, 0.97 }
					or (stop.isTurnIn and { 0.29, 0.87, 0.50 } or { 0.98, 0.78, 0.24 })
				btn:SetParent(canvas)
				btn:SetFrameStrata(canvas:GetFrameStrata() or "HIGH")
				btn:SetFrameLevel((canvas:GetFrameLevel() or 5) + 21)
				btn.bg:SetVertexColor(col[1], col[2], col[3], 0.95)
				if btn.core.SetColorTexture then
					btn.core:SetColorTexture(col[1] * 0.45, col[2] * 0.45, col[3] * 0.45, 0.95)
				end
				btn.lbl:SetText(tostring(stopIdx))
				btn:ClearAllPoints()
				btn:SetPoint("CENTER", canvas, "TOPLEFT", (stop.x / 100) * cw, -(stop.y / 100) * ch)
				local sRef = stop
				btn:SetScript("OnClick", function(_, mouseBtn)
					if mouseBtn == "RightButton" then
						_G.PluribusHiveDynamicRoute:SkipStop(sRef.id)
					else
						_G.PluribusHiveDynamicRoute:FocusStop(sRef.id)
					end
				end)
				btn:SetScript("OnEnter", function(selfBtn)
					GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
					local tag = (sRef.kind == "todo") and "|cff38bdf8[To-Do]|r "
						or (sRef.isTurnIn and "|cff4ade80[Abgabe]|r " or "|cfffbbf24[Quest]|r ")
					GameTooltip:SetText(string.format("#%d %s%s", stopIdx, tag, tostring(sRef.title)))
					if sRef.detail and sRef.detail ~= "" then
						GameTooltip:AddLine(tostring(sRef.detail), 0.85, 0.92, 1.0)
					end
					GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", tostring(sRef.zone), sRef.x, sRef.y), 0.70, 0.80, 0.90)
					GameTooltip:AddLine("Linksklick / Left-Click: Jetzt ansteuern", 0.29, 0.87, 0.50)
					GameTooltip:AddLine("Rechtsklick / Right-Click: " .. L("NAV_ROUTE_SKIP"), 0.98, 0.78, 0.24)
					GameTooltip:Show()
				end)
				btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
				btn:Show()
			end
		end
	end
end

function PluribusNavigationUI:RefreshWorldMapRoutePath()
	self:HideWorldMapRoutePath()
	if not _G.WorldMapFrame or not _G.WorldMapFrame:IsShown() then return end

	local canvas = self:GetWorldMapCanvas()
	if not canvas then return end
	local cw = canvas:GetWidth() or 0
	local ch = canvas:GetHeight() or 0
	if cw <= 10 or ch <= 10 then return end

	local viewedZone = self:GetCurrentViewedMapContext()
	self:RefreshWorldMapDynamicStops(canvas, cw, ch, viewedZone)

	if not self.activeWaypoint then return end
	local curZone = (GetRealZoneText and GetRealZoneText()) or ""
	local px, py = 0, 0
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			px, py = ux * 100, uy * 100
		end
	end

	local pf = _G.PluribusHivePathfinder
	local pathData = nil
	if pf and pf.GetRoutePathForMap then
		pathData = pf:GetRoutePathForMap(viewedZone, curZone, px, py)
	end

	-- Fallback when Pathfinder isn't loaded or has no multi-leg route: direct player->waypoint segment in same zone
	if (not pathData or (#pathData.segments == 0 and #pathData.pins == 0)) and self.activeWaypoint then
		local wp = self.activeWaypoint
		local vz = pf and pf.CanonicalZone and pf:CanonicalZone(viewedZone) or viewedZone
		local wz = pf and pf.CanonicalZone and pf:CanonicalZone(wp.zone) or wp.zone
		local cz = pf and pf.CanonicalZone and pf:CanonicalZone(curZone) or curZone
		if vz and wz and vz:lower() == wz:lower() then
			pathData = { segments = {}, pins = {} }
			if cz and cz:lower() == vz:lower() and (px > 0 or py > 0) then
				table.insert(pathData.segments, { x1 = px, y1 = py, x2 = wp.x, y2 = wp.y, mode = "road" })
			end
			table.insert(pathData.pins, {
				x = wp.x, y = wp.y, mode = "road",
				label = wp.name or wp.zone, zone = wp.zone,
				etaSec = 0, isFinal = true, isNext = true, legIdx = 1,
			})
		end
	end

	if not pathData or (#pathData.segments == 0 and #pathData.pins == 0) then return end

	if not self.worldMapRouteLayer then
		local layer = CreateFrame("Frame", "PluribusWorldMapRouteLayer", canvas)
		layer:EnableMouse(false)
		self.worldMapRouteLayer = layer
	end
	local layer = self.worldMapRouteLayer
	layer:SetParent(canvas)
	layer:ClearAllPoints()
	layer:SetAllPoints(canvas)
	layer:SetFrameStrata(canvas:GetFrameStrata() or "HIGH")
	layer:SetFrameLevel((canvas:GetFrameLevel() or 5) + 18)
	layer:Show()

	local lineIdx = 0
	local dotIdx = 0
	local canUseCreateLine = (layer.CreateLine ~= nil)

	for _, seg in ipairs(pathData.segments) do
		local x1 = (seg.x1 / 100) * cw
		local y1 = -(seg.y1 / 100) * ch
		local x2 = (seg.x2 / 100) * cw
		local y2 = -(seg.y2 / 100) * ch
		local col = GetRouteModeColor(seg.mode)

		if canUseCreateLine then
			lineIdx = lineIdx + 1
			local line = self.worldMapRouteLines[lineIdx]
			if not line then
				line = layer:CreateLine(nil, "OVERLAY")
				self.worldMapRouteLines[lineIdx] = line
			end
			line:SetThickness(3.5)
			if line.SetColorTexture then
				line:SetColorTexture(col[1], col[2], col[3], 0.88)
			elseif line.SetVertexColor then
				line:SetVertexColor(col[1], col[2], col[3], 0.88)
			end
			line:SetStartPoint("TOPLEFT", layer, x1, y1)
			line:SetEndPoint("TOPLEFT", layer, x2, y2)
			line:Show()
		end

		-- Crisp breadcrumb dots along the segment (provides direction rhythm & 100% fallback if CreateLine is absent)
		local segPxLen = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
		local stepPx = canUseCreateLine and 18 or 9
		local steps = math.min(48, math.max(1, math.floor(segPxLen / stepPx)))
		for s = 1, steps - 1 do
			if dotIdx >= 180 then break end
			local t = s / steps
			local dx = x1 + (x2 - x1) * t
			local dy = y1 + (y2 - y1) * t
			dotIdx = dotIdx + 1
			local dot = self.worldMapRouteDots[dotIdx]
			if not dot then
				dot = layer:CreateTexture(nil, "OVERLAY")
				self.worldMapRouteDots[dotIdx] = dot
			end
			local dotSz = canUseCreateLine and 5 or 6
			dot:SetSize(dotSz, dotSz)
			if dot.SetColorTexture then
				dot:SetColorTexture(col[1], col[2], col[3], 0.96)
			end
			dot:ClearAllPoints()
			dot:SetPoint("CENTER", layer, "TOPLEFT", dx, dy)
			dot:Show()
		end
	end

	-- Route waypoint node pins with mode colors & detailed hover tooltips
	for pIdx, pInfo in ipairs(pathData.pins) do
		if pIdx > 32 then break end
		local btn = self.worldMapRoutePins[pIdx]
		if not btn then
			btn = CreateFrame("Button", "PluribusWorldMapRoutePin" .. pIdx, canvas)
			btn:RegisterForClicks("RightButtonUp")
			local ring = btn:CreateTexture(nil, "BACKGROUND")
			ring:SetAllPoints()
			ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
			btn.ring = ring

			local core = btn:CreateTexture(nil, "OVERLAY")
			core:SetPoint("CENTER")
			btn.core = core

			local num = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			num:SetPoint("CENTER", btn, "CENTER", 0, 0)
			btn.num = num

			self.worldMapRoutePins[pIdx] = btn
		end

		local col = GetRouteModeColor(pInfo.mode)
		local sz = pInfo.isFinal and 22 or 16
		btn:SetParent(canvas)
		btn:SetSize(sz, sz)
		btn:SetFrameStrata(canvas:GetFrameStrata() or "HIGH")
		btn:SetFrameLevel((canvas:GetFrameLevel() or 5) + 22)
		btn.core:SetSize(sz - 6, sz - 6)

		if pInfo.isFinal then
			btn.core:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\CompassArrow")
			btn.core:SetVertexColor(1.0, 0.85, 0.20, 1.0)
			btn.ring:SetVertexColor(0.22, 0.88, 0.97, 1.0)
			btn.num:SetText("")
		else
			if btn.core.SetColorTexture then
				btn.core:SetColorTexture(col[1], col[2], col[3], 0.95)
			end
			btn.ring:SetVertexColor(col[1], col[2], col[3], 0.95)
			btn.num:SetText(tostring(pIdx))
		end

		btn:ClearAllPoints()
		btn:SetPoint("CENTER", canvas, "TOPLEFT", (pInfo.x / 100) * cw, -(pInfo.y / 100) * ch)

		btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		btn:SetScript("OnClick", function(_, mouseBtn)
			if mouseBtn == "RightButton" then
				PluribusNavigationUI:ClearWaypoint()
			elseif mouseBtn == "LeftButton" and (pInfo.mode == "portal" or pInfo.mode == "summon") and pInfo.providerName then
				if _G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.OpenWhisperPrompt then
					_G.PluribusHiveGuildTransit:OpenWhisperPrompt(pInfo.providerName, pInfo.mode, pInfo.label or pInfo.zone)
				end
			end
		end)
		btn:SetScript("OnEnter", function(selfBtn)
			GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
			local titlePrefix = pInfo.isFinal and "|cfffbbf24Destination:|r " or string.format("|cff38bdf8Step %d (%s):|r ", pIdx, tostring(pInfo.mode or "road"):upper())
			GameTooltip:SetText(titlePrefix .. tostring(pInfo.label))
			GameTooltip:AddLine(string.format("%s (%.1f, %.1f)", tostring(pInfo.zone), pInfo.x, pInfo.y), 0.82, 0.90, 0.98)
			if pInfo.providerName and (pInfo.mode == "portal" or pInfo.mode == "summon") then
				local pColor = (pInfo.mode == "summon") and "|cffc084fc" or "|cff60a5fa"
				GameTooltip:AddLine(string.format("%sGuild %s:|r %s", pColor, tostring(pInfo.spellLabel or pInfo.mode), tostring(pInfo.providerName)), 1, 1, 1)
				if pInfo.mode == "summon" and pInfo.helperPenaltySec and pInfo.helperPenaltySec > 0 then
					GameTooltip:AddLine(string.format("Includes +%ds 2-helper buffer (%d guildmate(s) in zone)", math.floor(pInfo.helperPenaltySec), tonumber(pInfo.nearbyHelpers) or 0), 0.98, 0.78, 0.24)
				end
				GameTooltip:AddLine("Left-Click: " .. L("NAV_ASK_WHISPER") .. " " .. tostring(pInfo.providerName), 0.29, 0.87, 0.50)
			end
			if pInfo.etaSec and pInfo.etaSec > 0 then
				local tag = pInfo.isSynced and "Hive" or L("NAV_ESTIMATED")
				GameTooltip:AddLine(string.format("Leg ETA: ~%ds (%s)", math.floor(pInfo.etaSec), tag), 0.29, 0.87, 0.50)
			end
			if pInfo.waitSec and pInfo.waitSec > 0 and pInfo.mode ~= "portal" and pInfo.mode ~= "summon" then
				GameTooltip:AddLine(string.format("Est. Wait: ~%ds", math.floor(pInfo.waitSec)), 0.98, 0.78, 0.24)
			end
			GameTooltip:AddLine("Right-Click: " .. L("NAV_CLEAR_ROUTE"), 0.97, 0.44, 0.44)
			GameTooltip:Show()
		end)
		btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
		btn:Show()
	end
end

-- ============================================================================
-- MINIMAP ROUTE PATH OVERLAY (Live Dotted Breadcrumb Trail + Rim Indicator)
-- ============================================================================
local MINIMAP_OUTDOOR_YARDS = { [0] = 233, [1] = 200, [2] = 166, [3] = 133, [4] = 100, [5] = 66 }
local MINIMAP_INDOOR_YARDS  = { [0] = 150, [1] = 120, [2] = 90,  [3] = 60,  [4] = 40,  [5] = 25 }

function PluribusNavigationUI:HideMinimapRoutePath()
	for _, dt in ipairs(self.minimapRouteDots) do
		if dt and dt.Hide then dt:Hide() end
	end
	if self.minimapEdgePip then
		self.minimapEdgePip:Hide()
	end
end

function PluribusNavigationUI:EnsureMinimapRouteLayer()
	if self.minimapRouteLayer then return self.minimapRouteLayer end
	if not _G.Minimap then return nil end

	local layer = CreateFrame("Frame", "PluribusMinimapRouteLayer", _G.Minimap)
	layer:SetAllPoints(_G.Minimap)
	layer:SetFrameStrata(_G.Minimap:GetFrameStrata() or "LOW")
	layer:SetFrameLevel((_G.Minimap:GetFrameLevel() or 2) + 8)
	layer:EnableMouse(false)

	local pip = layer:CreateTexture(nil, "OVERLAY")
	pip:SetSize(12, 12)
	pip:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\CompassArrow")
	pip:SetVertexColor(1.0, 0.85, 0.20, 1.0)
	pip:Hide()
	self.minimapEdgePip = pip

	local accum = 0
	layer:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + (elapsed or 0)
		if accum < 0.12 then return end
		accum = 0
		PluribusNavigationUI:UpdateMinimapRoutePath()
	end)

	self.minimapRouteLayer = layer
	return layer
end

function PluribusNavigationUI:UpdateMinimapRoutePath()
	self:HideMinimapRoutePath()
	if not self.activeWaypoint or not _G.Minimap or not _G.Minimap:IsShown() then return end
	if IsInInstance then
		local inInst = IsInInstance()
		if inInst then return end
	end

	local layer = self:EnsureMinimapRouteLayer()
	if not layer then return end

	local px, py = 0, 0
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			px, py = ux * 100, uy * 100
		end
	end
	if px == 0 and py == 0 then return end

	local curZone = (GetRealZoneText and GetRealZoneText()) or ""
	local pf = _G.PluribusHivePathfinder
	local pathData = (pf and pf.GetRoutePathForMap) and pf:GetRoutePathForMap(curZone, curZone, px, py) or nil

	-- Fallback single direct segment if Pathfinder has no zone-matched segment yet
	if (not pathData or #pathData.segments == 0) and self.activeWaypoint then
		local wp = self.activeWaypoint
		local cz = pf and pf.CanonicalZone and pf:CanonicalZone(curZone) or curZone
		local wz = pf and pf.CanonicalZone and pf:CanonicalZone(wp.zone) or wp.zone
		if cz and wz and cz:lower() == wz:lower() then
			pathData = {
				segments = { { x1 = px, y1 = py, x2 = wp.x, y2 = wp.y, mode = "road" } },
				pins = { { x = wp.x, y = wp.y, mode = "road", isFinal = true } },
			}
		end
	end
	if not pathData or #pathData.segments == 0 then return end

	local zoom = (_G.Minimap.GetZoom and _G.Minimap:GetZoom()) or 0
	local indoors = (IsIndoors and IsIndoors()) == true
	local radiusYards = (indoors and MINIMAP_INDOOR_YARDS[zoom]) or MINIMAP_OUTDOOR_YARDS[zoom] or 166
	local halfW = (_G.Minimap:GetWidth() or 140) * 0.5
	local maxR = halfW * 0.88
	local zoneW, zoneH = 2800, 2800
	if _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.GetZoneDims then
		zoneW, zoneH = _G.PluribusHiveTerrainMesh:GetZoneDims(curZone)
	end

	local rotate = (GetCVar and GetCVar("rotateMinimap") == "1")
	local facing = (rotate and GetPlayerFacing and GetPlayerFacing()) or 0
	local cosF = rotate and math.cos(facing) or 1
	local sinF = rotate and math.sin(facing) or 0

	local function ProjectToMinimap(tx, ty)
		local dxYds = ((tx - px) / 100) * zoneW
		local dyYds = -((ty - py) / 100) * zoneH -- screen Y is up (+), map Y is down (+)
		local mx = (dxYds / radiusYards) * halfW
		local my = (dyYds / radiusYards) * halfW
		if rotate then
			local rx = mx * cosF - my * sinF
			local ry = mx * sinF + my * cosF
			return rx, ry
		end
		return mx, my
	end

	local dotIdx = 0
	local maxDots = 44
	local firstSegColor = GetRouteModeColor(pathData.segments[1].mode)
	local rimX, rimY, rimAngle = nil, nil, 0

	for sIdx, seg in ipairs(pathData.segments) do
		local x1, y1 = ProjectToMinimap(seg.x1, seg.y1)
		local x2, y2 = ProjectToMinimap(seg.x2, seg.y2)
		local col = GetRouteModeColor(seg.mode)
		local segLen = math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)

		if sIdx == 1 and segLen > 2 then
			local distToEnd = math.sqrt(x2 * x2 + y2 * y2)
			if distToEnd > maxR then
				local ang = math.atan2(y2, x2)
				rimX = math.cos(ang) * maxR
				rimY = math.sin(ang) * maxR
				rimAngle = ang - (math.pi / 2)
			else
				rimX = x2
				rimY = y2
				rimAngle = math.atan2(y2 - y1, x2 - x1) - (math.pi / 2)
			end
		end

		local steps = math.min(28, math.max(1, math.floor(segLen / 7)))
		for k = 1, steps do
			if dotIdx >= maxDots then break end
			local t = k / steps
			local cx = x1 + (x2 - x1) * t
			local cy = y1 + (y2 - y1) * t
			local r = math.sqrt(cx * cx + cy * cy)
			if r >= 6 and r <= maxR then
				dotIdx = dotIdx + 1
				local dot = self.minimapRouteDots[dotIdx]
				if not dot then
					dot = layer:CreateTexture(nil, "OVERLAY")
					self.minimapRouteDots[dotIdx] = dot
				end
				dot:SetSize(4, 4)
				if dot.SetColorTexture then
					dot:SetColorTexture(col[1], col[2], col[3], 0.94)
				end
				dot:ClearAllPoints()
				dot:SetPoint("CENTER", layer, "CENTER", cx, cy)
				dot:Show()
			end
		end
	end

	-- Show directional pip at target (if inside minimap) or on minimap rim (if farther away)
	if self.minimapEdgePip and rimX and rimY then
		self.minimapEdgePip:SetVertexColor(firstSegColor[1], firstSegColor[2], firstSegColor[3], 1.0)
		self.minimapEdgePip:ClearAllPoints()
		self.minimapEdgePip:SetPoint("CENTER", layer, "CENTER", rimX, rimY)
		if self.minimapEdgePip.SetRotation then
			pcall(self.minimapEdgePip.SetRotation, self.minimapEdgePip, rimAngle)
		end
		self.minimapEdgePip:Show()
	end
end

-- ============================================================================
-- COMPASS ARROW HUD (Powered by Smart Multi-Modal Pathfinder!)
-- ============================================================================
function PluribusNavigationUI:EnsureCompassHUD()
	if self.hudFrame then return self.hudFrame end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end

	local hud = CreateFrame("Frame", "PluribusCompassHUD", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	hud:SetSize(276, 78)
	hud:SetPoint("TOP", UIParent, "TOP", 0, -110)
	hud:SetFrameStrata("HIGH")
	hud:SetMovable(true)
	hud:EnableMouse(true)
	hud:SetClampedToScreen(true)
	hud:RegisterForDrag("LeftButton")
	hud:SetScript("OnDragStart", function(f) f:StartMoving() end)
	hud:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
	local p = UI.palette
	UI:ApplyBackdrop(hud, p.bg[1], p.bg[2], p.bg[3], p.bg[4], p.border[1], p.border[2], p.border[3], p.border[4])

	local dial = CreateFrame("Frame", nil, hud, BackdropTemplateMixin and "BackdropTemplate" or nil)
	dial:SetSize(48, 48)
	dial:SetPoint("LEFT", hud, "LEFT", 8, 0)
	UI:ApplyBackdrop(dial, p.header[1], p.header[2], p.header[3], 0.98, p.accent[1], p.accent[2], p.accent[3], 0.85)

	local arrow = dial:CreateTexture(nil, "ARTWORK")
	arrow:SetSize(36, 36)
	arrow:SetPoint("CENTER", dial, "CENTER", 0, 0)
	arrow:SetTexture("Interface\\AddOns\\PluribusCore\\Media\\CompassArrow")
	hud.arrow = arrow

	local title = hud:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", dial, "TOPRIGHT", 8, 4)
	title:SetWidth(182)
	title:SetJustifyH("LEFT")
	title:SetText("|cff38bdf8Compass Ready|r")
	hud.title = title

	local meta = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	meta:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	meta:SetWidth(196)
	meta:SetJustifyH("LEFT")
	meta:SetTextColor(0.80, 0.88, 0.96, 1)
	meta:SetText("")
	hud.meta = meta

	local dist = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dist:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -2)
	dist:SetWidth(196)
	dist:SetJustifyH("LEFT")
	dist:SetTextColor(0.29, 0.87, 0.50, 1)
	dist:SetText("")
	hud.dist = dist

	local routeInfo = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	routeInfo:SetPoint("BOTTOMLEFT", dial, "BOTTOMRIGHT", 8, -3)
	routeInfo:SetWidth(148)
	routeInfo:SetJustifyH("LEFT")
	routeInfo:SetTextColor(0.95, 0.78, 0.30, 1)
	routeInfo:SetText("")
	hud.routeInfo = routeInfo

	local closeBtn = UI:CreateButton(hud, "X", 20, 18, function()
		PluribusNavigationUI:ClearWaypoint()
		hud:Hide()
	end)
	closeBtn:SetPoint("TOPRIGHT", hud, "TOPRIGHT", -5, -5)

	local skipBtn = UI:CreateButton(hud, L("NAV_ROUTE_SKIP"), 50, 18, function()
		if _G.PluribusHiveDynamicRoute and _G.PluribusHiveDynamicRoute.SkipActiveStop then
			_G.PluribusHiveDynamicRoute:SkipActiveStop()
		end
	end)
	skipBtn:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -5, 5)
	skipBtn:Hide()
	hud.skipBtn = skipBtn

	local whisperBtn = UI:CreateButton(hud, L("NAV_ASK_WHISPER"), 54, 18, function()
		local ctx = hud._transitWhisper
		if ctx and ctx.providerName and _G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.OpenWhisperPrompt then
			_G.PluribusHiveGuildTransit:OpenWhisperPrompt(ctx.providerName, ctx.mode, ctx.destLabel)
		end
	end, true)
	whisperBtn:SetPoint("BOTTOMRIGHT", hud, "BOTTOMRIGHT", -5, 5)
	whisperBtn:Hide()
	hud.whisperBtn = whisperBtn

	-- Live smart turn-by-turn compass bearing loop (uses HivePathfinder active leg, NOT straight-line!)
	local accum = 0
	hud:SetScript("OnUpdate", function(selfHud, elapsed)
		accum = accum + (elapsed or 0)
		if accum < 0.08 then return end
		accum = 0
		local wp = PluribusNavigationUI.activeWaypoint
		if not wp then return end

		local curZone = (GetRealZoneText and GetRealZoneText()) or wp.zone or "Azeroth"
		local px, py = 0, 0
		if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
			local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
			px, py = (ux or 0) * 100, (uy or 0) * 100
		end

		local targetX, targetY = wp.x or 50, wp.y or 50
		local legLine = ""
		local modeColor = { 0.22, 0.88, 0.97 }

		-- Ask Smart Pathfinder for the next road/pass/water/flight/ship/portal/summon leg!
		selfHud._transitWhisper = nil
		if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.GetActiveLeg then
			local leg = _G.PluribusHivePathfinder:GetActiveLeg(curZone, px, py)
			if leg then
				if leg.x and leg.y then
					targetX, targetY = leg.x, leg.y
				end
				local legMode = tostring(leg.mode or "road"):lower()
				if legMode == "portal" then
					local who = leg.providerName and (" · " .. tostring(leg.providerName)) or ""
					legLine = "|cff60a5fa[" .. L("NAV_LEG_PORTAL") .. "]|r " .. tostring(leg.label or leg.zone) .. who
					modeColor = { 0.38, 0.72, 1.00 }
					if leg.providerName then
						selfHud._transitWhisper = { providerName = leg.providerName, mode = "portal", destLabel = leg.label or leg.zone }
					end
				elseif legMode == "summon" then
					local who = leg.providerName and (" · " .. tostring(leg.providerName)) or ""
					legLine = "|cffc084fc[" .. L("NAV_LEG_SUMMON") .. "]|r " .. tostring(leg.label or leg.zone) .. who
					modeColor = { 0.75, 0.45, 0.98 }
					if leg.providerName then
						selfHud._transitWhisper = { providerName = leg.providerName, mode = "summon", destLabel = leg.label or leg.zone }
					end
				elseif legMode == "flight" then
					local syncTag = (leg.isSynced or leg.synced) and "Hive" or L("NAV_ESTIMATED")
					local durTxt = leg.etaSec and string.format(" (%ds · %s)", math.floor(leg.etaSec), syncTag) or ""
					legLine = "|cff38bdf8[" .. L("NAV_LEG_FLIGHT") .. "]|r -> " .. tostring(leg.label or leg.zone) .. durTxt
					modeColor = { 0.22, 0.74, 0.97 }
				elseif legMode == "boat" or legMode == "zeppelin" then
					local waitTxt = ""
					if leg.waitSec then
						local syncTag = (leg.isSynced or leg.synced) and L("NAV_SYNCED") or L("NAV_ESTIMATED")
						waitTxt = string.format(" (%ds · %s)", math.floor(leg.waitSec), syncTag)
					end
					legLine = "|cfffbbf24[" .. L(legMode == "boat" and "NAV_LEG_BOAT" or "NAV_LEG_ZEPPELIN") .. "]|r " .. tostring(leg.label or "") .. waitTxt
					modeColor = { 0.98, 0.78, 0.24 }
				elseif legMode == "water" then
					legLine = "|cff22d3ee[" .. L("NAV_LEG_WATER") .. "]|r -> " .. tostring(leg.label or leg.zone)
					modeColor = { 0.13, 0.83, 0.93 }
				else
					legLine = "|cff4ade80[" .. L("NAV_LEG_ROAD") .. "]|r -> " .. tostring(leg.label or leg.zone)
					modeColor = { 0.29, 0.87, 0.50 }
				end
			end
		end
		local showWhisper = (selfHud._transitWhisper ~= nil)
		local showSkip = (wp._fromDynamicRoute == true)
		if selfHud.whisperBtn then
			if showWhisper then
				selfHud.whisperBtn:Show()
			else
				selfHud.whisperBtn:Hide()
			end
		end
		if selfHud.skipBtn then
			if showSkip then
				selfHud.skipBtn:ClearAllPoints()
				if showWhisper and selfHud.whisperBtn then
					selfHud.skipBtn:SetPoint("RIGHT", selfHud.whisperBtn, "LEFT", -4, 0)
				else
					selfHud.skipBtn:SetPoint("BOTTOMRIGHT", selfHud, "BOTTOMRIGHT", -5, 5)
				end
				selfHud.skipBtn:Show()
			else
				selfHud.skipBtn:Hide()
			end
		end

		local dx = targetX - px
		local dy = targetY - py
		local pf = _G.PluribusHivePathfinder
		local yards = (pf and pf.DistanceYards)
			and math.floor(pf:DistanceYards(curZone, px, py, targetX, targetY))
			or math.floor(math.sqrt(dx * dx + dy * dy) * 28)

		local facing = (GetPlayerFacing and GetPlayerFacing()) or 0
		local targetAngle = math.atan2(-dx, -dy)
		local relAngle = targetAngle - facing
		if selfHud.arrow.SetRotation then
			pcall(selfHud.arrow.SetRotation, selfHud.arrow, relAngle)
		end
		if selfHud.arrow.SetVertexColor then
			selfHud.arrow:SetVertexColor(modeColor[1], modeColor[2], modeColor[3], 1)
		end

		local finalYards = (pf and pf.DistanceYards)
			and pf:DistanceYards(curZone, px, py, wp.x or 50, wp.y or 50)
			or (math.sqrt(((wp.x or 50) - px)^2 + ((wp.y or 50) - py)^2) * 28)
		if curZone:lower() == (wp.zone or ""):lower() and finalYards < 18 then
			selfHud.dist:SetText("|cff4ade80" .. L("NAV_ARRIVED") .. "|r")
		else
			local etaTxt = ""
			local activeR = pf and pf.activeRoute
			local totalSec = activeR and (activeR.totalEtaSec or activeR.totalSec)
			if totalSec and totalSec > 0 then
				local sec = math.floor(totalSec)
				etaTxt = sec >= 60 and string.format(" · ETA %dm%ds", math.floor(sec / 60), sec % 60) or string.format(" · ETA %ds", sec)
			end
			selfHud.dist:SetText(string.format("|cff4ade80~%d yds|r |cff94a3b8(%.1f, %.1f)%s|r", yards, targetX, targetY, etaTxt))
		end

		selfHud.routeInfo:SetText(legLine)
	end)

	hud:Hide()
	self.hudFrame = hud
	return hud
end

function PluribusNavigationUI:ToggleCompassHUD()
	local hud = self:EnsureCompassHUD()
	if not hud then return end
	if hud:IsShown() then
		hud:Hide()
	else
		hud:Show()
		if self.activeWaypoint then
			hud.title:SetText("|cff38bdf8" .. tostring(self.activeWaypoint.name):sub(1, 24) .. "|r")
			hud.meta:SetText(tostring(self.activeWaypoint.zone or "Azeroth"))
		else
			hud.title:SetText("|cff38bdf8Pluribus Pathfinder|r")
			hud.meta:SetText("Alt+Klick Karte · /nav · /way X Y")
			hud.dist:SetText("")
			hud.routeInfo:SetText("")
		end
	end
end

function PluribusNavigationUI:ClearWaypoint()
	self.activeWaypoint = nil
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.ClearRoute then
		_G.PluribusHivePathfinder:ClearRoute()
	end
	if C_Map and C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
	if self.hudFrame then
		if self.hudFrame.skipBtn then self.hudFrame.skipBtn:Hide() end
		self.hudFrame:Hide()
	end
	self:HideWorldMapRoutePath()
	self:HideMinimapRoutePath()
	if self.mainWindow and self.mainWindow:IsShown() then self:Refresh() end
end

function PluribusNavigationUI:SetWaypoint(name, zone, x, y, mapID, opts)
	opts = type(opts) == "table" and opts or {}
	local nx = math.max(0, math.min(100, tonumber(x) or 50))
	local ny = math.max(0, math.min(100, tonumber(y) or 50))
	local destZone = tostring(zone or (GetRealZoneText and GetRealZoneText()) or "Azeroth")
	self.activeWaypoint = {
		name = tostring(name or "Waypoint"),
		zone = destZone,
		x = nx,
		y = ny,
		mapID = tonumber(mapID) or 0,
		_fromDynamicRoute = opts.fromDynamicRoute == true,
		_stopId = opts.stopId,
		_stopIndex = opts.stopIndex,
		_stopTotal = opts.stopTotal,
	}

	-- Compute multi-modal optimal route (roads, barriers, water/Robbe, discovered FPs, guild-synced ships, level safety!)
	local routeSummary = destZone
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.SetRouteTo then
		local curZone = (GetRealZoneText and GetRealZoneText()) or destZone
		local px, py = 50, 50
		if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
			local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
			if ux and uy and (ux > 0 or uy > 0) then
				px, py = ux * 100, uy * 100
			end
		end
		local route = _G.PluribusHivePathfinder:SetRouteTo(curZone, px, py, destZone, nx, ny, self.activeWaypoint.name)
		if route and route.summary then
			routeSummary = route.summary
		end
	end

	-- Sync WoW's internal UserWaypoint & SuperTrack to the FIRST ACTIVE ROAD/MESH LEG (turn-by-turn, not straight through walls!)
	local syncedNativeLeg = false
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.activeRoute and _G.PluribusHivePathfinder.activeRoute.legs then
		local firstLeg = _G.PluribusHivePathfinder.activeRoute.legs[1]
		if firstLeg and _G.PluribusHiveTerrainMesh and _G.PluribusHiveTerrainMesh.SyncNativeWaypointToActiveLeg then
			syncedNativeLeg = _G.PluribusHiveTerrainMesh:SyncNativeWaypointToActiveLeg(firstLeg)
		end
	end
	if not syncedNativeLeg and mapID and mapID > 0 and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
		pcall(function()
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, nx / 100, ny / 100))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			end
		end)
	end
	if _G.PluribusNavigator and _G.PluribusNavigator.SetWaypoint then
		pcall(function() _G.PluribusNavigator:SetWaypoint(nx, ny, self.activeWaypoint.name) end)
	end

	local hud = self:EnsureCompassHUD()
	if hud then
		local idxBadge = (opts.fromDynamicRoute and opts.stopIndex and opts.stopTotal)
			and string.format("|cff94a3b8(%d/%d)|r ", opts.stopIndex, opts.stopTotal) or ""
		hud.title:SetText(idxBadge .. "|cff38bdf8" .. self.activeWaypoint.name:sub(1, 24) .. "|r")
		hud.meta:SetText(routeSummary:sub(1, 36))
		if hud.skipBtn then
			hud.skipBtn:SetShown(opts.fromDynamicRoute == true)
		end
		hud:Show()
	end

	self:EnsureMinimapRouteLayer()
	self:UpdateMinimapRoutePath()
	self:RefreshWorldMapRoutePath()

	if not opts.silent and _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification(string.format("|cff4ade80Pathfinder:|r %s — %s", self.activeWaypoint.name, routeSummary), 3.5)
	end
	if self.mainWindow and self.mainWindow:IsShown() then self:Refresh() end
end

-- Extract normalized 0..100 World Map coordinates cleanly across zoomed ScrollContainer & legacy WorldMapButton
function PluribusNavigationUI:GetWorldMapClickCoords(clickedFrame)
	local wm = _G.WorldMapFrame
	if wm and wm.ScrollContainer and wm.ScrollContainer.GetNormalizedCursorPosition then
		local ok, ux, uy = pcall(wm.ScrollContainer.GetNormalizedCursorPosition, wm.ScrollContainer)
		if ok and type(ux) == "number" and type(uy) == "number" and ux >= 0 and ux <= 1 and uy >= 0 and uy <= 1 then
			return ux * 100, uy * 100
		end
	end

	local cx, cy = GetCursorPosition and GetCursorPosition()
	if not cx or not cy then return nil, nil end
	local canvas = (clickedFrame and clickedFrame.GetLeft and clickedFrame:GetLeft()) and clickedFrame or self:GetWorldMapCanvas()
	if not canvas or not canvas.GetLeft then return nil, nil end
	local scale = (canvas.GetEffectiveScale and canvas:GetEffectiveScale()) or 1
	cx, cy = cx / scale, cy / scale
	local left, top = canvas:GetLeft(), canvas:GetTop()
	local w, h = canvas:GetWidth(), canvas:GetHeight()
	if left and top and w and h and w > 0 and h > 0 then
		local nx = ((cx - left) / w) * 100
		local ny = ((top - cy) / h) * 100
		if nx >= 0 and nx <= 100 and ny >= 0 and ny <= 100 then
			return nx, ny
		end
	end
	return nil, nil
end

function PluribusNavigationUI:HandleWorldMapModifierClick(clickedFrame, mouseBtn)
	if mouseBtn and mouseBtn ~= "LeftButton" then return false end
	local altDown = (IsAltKeyDown and IsAltKeyDown()) == true
	local ctrlDown = (IsControlKeyDown and IsControlKeyDown()) == true
	if not altDown and not ctrlDown then return false end

	-- Debounce so multiple hooked map layers never double-fire on a single click
	local now = (GetTime and GetTime()) or 0
	if now > 0 and (now - (self._lastMapClickAt or 0)) < 0.18 then
		return true
	end

	local nx, ny = self:GetWorldMapClickCoords(clickedFrame)
	if not nx or not ny then return false end

	self._lastMapClickAt = now
	nx = math.floor(nx * 10 + 0.5) / 10
	ny = math.floor(ny * 10 + 0.5) / 10
	local zone, mapID = self:GetCurrentViewedMapContext()

	if ctrlDown then
		-- Ctrl + Left-Click: save persistent Pin AND start navigation
		local pin = self:AddPin(nil, zone, nx, ny, mapID)
		if pin then
			self:SetWaypoint(pin.name, pin.zone, pin.x, pin.y, pin.mapID)
		end
	else
		-- Alt + Left-Click: start Smart Pathfinder navigation immediately!
		local label = string.format("%s (%.1f, %.1f)", tostring(zone or "Azeroth"), nx, ny)
		self:SetWaypoint(label, zone, nx, ny, mapID)
	end
	return true
end

-- Attach World Map side tab + Alt+Left-Click Instant Nav + Ctrl+Left-Click Pin Placement + Route Overlay!
function PluribusNavigationUI:AttachToWorldMap()
	local host = _G.WorldMapFrame
	if not host or not _G.PluribusUIFramework then return end

	local function HookMapClickTarget(target)
		if not target or target._plbPinHooked or not target.HookScript then return end
		target._plbPinHooked = true
		pcall(target.HookScript, target, "OnMouseDown", function(selfCanvas, mouseBtn)
			PluribusNavigationUI:HandleWorldMapModifierClick(selfCanvas, mouseBtn)
		end)
		pcall(target.HookScript, target, "OnMouseUp", function(selfCanvas, mouseBtn)
			PluribusNavigationUI:HandleWorldMapModifierClick(selfCanvas, mouseBtn)
		end)
	end

	local function HookAllMapClickTargets()
		HookMapClickTarget(self:GetWorldMapCanvas())
		if host.ScrollContainer then
			HookMapClickTarget(host.ScrollContainer)
			if host.ScrollContainer.Child then
				HookMapClickTarget(host.ScrollContainer.Child)
			end
		end
		if _G.WorldMapButton then HookMapClickTarget(_G.WorldMapButton) end
		if _G.WorldMapDetailFrame then HookMapClickTarget(_G.WorldMapDetailFrame) end
		if hooksecurefunc and _G.WorldMapButton_OnClick and not self._worldMapButtonFnHooked then
			self._worldMapButtonFnHooked = true
			pcall(hooksecurefunc, "WorldMapButton_OnClick", function(btnFrame, mouseBtn)
				PluribusNavigationUI:HandleWorldMapModifierClick(btnFrame, mouseBtn)
			end)
		end
	end

	HookAllMapClickTargets()
	if self.worldMapAttached then return end
	self.worldMapAttached = true

	local UI = _G.PluribusUIFramework
	if not _G.PluribusHive or _G.PluribusHive:GetConfig().attachSideTabs ~= false then
		local tab = UI:CreateSideTab(host, 1, {
			icon = "Interface\\Icons\\INV_Misc_Map_01",
			title = L("NAV_TITLE"),
			tooltip = L("NAV_PINS_HINT"),
			yOffset = -64,
			onClick = function()
				if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
					_G.PluribusMainFrame:OpenToTab("Navigation")
				else
					PluribusNavigationUI:Toggle()
				end
			end,
		})
		host._plbNavSideTab = tab
	end

	if host.HookScript then
		pcall(host.HookScript, host, "OnShow", function()
			HookAllMapClickTargets()
			PluribusNavigationUI:RefreshWorldMapPins()
		end)
		local wmAccum = 0
		pcall(host.HookScript, host, "OnUpdate", function(_, elapsed)
			if not PluribusNavigationUI.activeWaypoint then return end
			wmAccum = wmAccum + (elapsed or 0)
			if wmAccum < 0.45 then return end
			wmAccum = 0
			PluribusNavigationUI:RefreshWorldMapRoutePath()
		end)
	end
	if hooksecurefunc and _G.WorldMapFrame_Update then
		pcall(hooksecurefunc, "WorldMapFrame_Update", function()
			PluribusNavigationUI:RefreshWorldMapPins()
		end)
	end
	if hooksecurefunc and host.OnMapChanged then
		pcall(hooksecurefunc, host, "OnMapChanged", function()
			PluribusNavigationUI:RefreshWorldMapPins()
		end)
	end
end

-- Shared graphical Navigation renderer (Smart Pathfinder + World Map Pins + Guild GPS)
function PluribusNavigationUI:RenderEmbedded(parent, width, height, onRefresh)
	local UI = _G.PluribusUIFramework
	if not UI or not parent then return end
	width = width or 724
	height = height or 440

	local pf = _G.PluribusHivePathfinder
	local routeMeta = (pf and pf.activeRoute and pf.activeRoute.summary) or nil
	local activeSub = self.activeWaypoint
		and string.format("|cff4ade80Route:|r %s — %s", self.activeWaypoint.name, routeMeta or string.format("%s (%.1f, %.1f)", self.activeWaypoint.zone, self.activeWaypoint.x, self.activeWaypoint.y))
		or L("NAV_PINS_HINT")
	local banner = UI:CreateBannerCard(parent, width, 56, "Interface\\AddOns\\PluribusCore\\Media\\CompassArrow",
		"|cff38bdf8" .. L("NAV_TITLE") .. "|r", activeSub, 0.22, 0.74, 0.97)
	banner:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -10)

	local hudBtn = UI:CreateButton(banner, (self.hudFrame and self.hudFrame:IsShown()) and L("NAV_COMPASS_HIDE") or L("NAV_COMPASS_SHOW"), 114, 24, function()
		PluribusNavigationUI:ToggleCompassHUD()
		if onRefresh then onRefresh() end
	end, true)
	hudBtn:SetPoint("RIGHT", banner, "RIGHT", -10, 0)

	if self.activeWaypoint then
		local clrBtn = UI:CreateButton(banner, L("NAV_CLEAR_ROUTE"), 92, 24, function()
			PluribusNavigationUI:ClearWaypoint()
			if onRefresh then onRefresh() end
		end)
		clrBtn:SetPoint("RIGHT", hudBtn, "LEFT", -6, 0)
	end

	-- Quick Pin & Coordinate Bar + "Pin Here"
	local formCard = UI:CreateCard(parent, width, 40)
	formCard:SetPoint("TOPLEFT", banner, "BOTTOMLEFT", 0, -8)

	local nLbl = UI:CreateLabel(formCard, "Pin:", 0.78, 0.86, 0.94)
	nLbl:SetPoint("LEFT", formCard, "LEFT", 8, 0)
	local nBox = UI:CreateInputBox(formCard, 150, 22)
	nBox:SetPoint("LEFT", nLbl, "RIGHT", 6, 0)
	nBox:SetText("Mein Pin")

	local xLbl = UI:CreateLabel(formCard, "X:", 0.78, 0.86, 0.94)
	xLbl:SetPoint("LEFT", nBox, "RIGHT", 8, 0)
	local xBox = UI:CreateInputBox(formCard, 46, 22)
	xBox:SetPoint("LEFT", xLbl, "RIGHT", 4, 0)
	xBox:SetText("50.0")

	local yLbl = UI:CreateLabel(formCard, "Y:", 0.78, 0.86, 0.94)
	yLbl:SetPoint("LEFT", xBox, "RIGHT", 8, 0)
	local yBox = UI:CreateInputBox(formCard, 46, 22)
	yBox:SetPoint("LEFT", yLbl, "RIGHT", 4, 0)
	yBox:SetText("50.0")

	local pinBtn = UI:CreateButton(formCard, "+ Pin & Navi", 96, 24, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
		local pin = PluribusNavigationUI:AddPin(nBox:GetText(), zone, xBox:GetText(), yBox:GetText())
		if pin then
			PluribusNavigationUI:SetWaypoint(pin.name, pin.zone, pin.x, pin.y)
		end
		if onRefresh then onRefresh() end
	end, true)
	pinBtn:SetPoint("LEFT", yBox, "RIGHT", 8, 0)

	local hereBtn = UI:CreateButton(formCard, L("NAV_PIN_CURRENT"), 92, 24, function()
		local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
		local px, py, mid = 50, 50, 0
		if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
			local ux, uy, m = _G.PluribusUtils:GetUnitMapPosition("player")
			px, py, mid = (ux or 0.5) * 100, (uy or 0.5) * 100, m or 0
		end
		PluribusNavigationUI:AddPin(nBox:GetText() ~= "Mein Pin" and nBox:GetText() or nil, zone, px, py, mid)
		PluribusNavigationUI.selectedCat = "Pins"
		if onRefresh then onRefresh() end
	end)
	hereBtn:SetPoint("LEFT", pinBtn, "RIGHT", 6, 0)

	-- Category Tabs (Dynamic Route | Map Pins | Port & Summon | Raids | Dungeons | Cities | Bosses | Guild GPS)
	local pins = self:GetPinsDB()
	local dynRoute = _G.PluribusHiveDynamicRoute
	local dynActive, dynSkipped = {}, {}
	if dynRoute and dynRoute.GetActiveAndSkipped then
		dynActive, dynSkipped = dynRoute:GetActiveAndSkipped()
	end
	local gtProviders = (_G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.GetEligibleProviders)
		and _G.PluribusHiveGuildTransit:GetEligibleProviders()
		or { mages = {}, warlocks = {}, all = {}, skippedInstanced = 0 }
	local transitCount = #(gtProviders.all or {})
	local cats = {
		{ key = "Route",    label = L("NAV_CAT_ROUTE") .. " (" .. #dynActive .. ")", w = 84 },
		{ key = "Pins",     label = L("NAV_CAT_PINS") .. " (" .. #pins .. ")", w = 78 },
		{ key = "Transit",  label = L("NAV_CAT_TRANSIT") .. " (" .. transitCount .. ")", w = 104 },
		{ key = "Raids",    label = L("NAV_CAT_RAIDS"),    w = 52 },
		{ key = "Dungeons", label = L("NAV_CAT_DUNGEONS"), w = 70 },
		{ key = "Cities",   label = L("NAV_CAT_CITIES"),   w = 56 },
		{ key = "Bosses",   label = L("NAV_CAT_BOSSES"),   w = 68 },
		{ key = "Guild",    label = L("NAV_CAT_GUILD"),    w = 72 },
	}
	local catX = 12
	for _, cat in ipairs(cats) do
		local b = UI:CreateButton(parent, cat.label, cat.w, 24, function()
			PluribusNavigationUI.selectedCat = cat.key
			if onRefresh then onRefresh() end
		end)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", catX, -120)
		b:SetActiveState(self.selectedCat == cat.key)
		catX = catX + cat.w + 4
	end

	-- Pathfinder Speed & Mode Summary Strip
	local speedStrip = ""
	if pf and pf.GetTravelProfile then
		local prof = pf:GetTravelProfile()
		local fpCount = pf.GetDiscoveredFlightCount and pf:GetDiscoveredFlightCount() or 0
		local avoidStr = prof.avoidHighLevel and "|cff4ade80Safe Roads|r" or "|cfffbbf24Direct|r"
		local gtStr = prof.useGuildTransit
			and string.format("|cff60a5fa%dM|r/|cffc084fc%dW|r", #(gtProviders.mages or {}), #(gtProviders.warlocks or {}))
			or "|cff94a3b8OFF|r"
		speedStrip = string.format("Land: |cff38bdf8%d%%|r · Wasser: |cff22d3ee%d%%|r · FPs: |cfffbbf24%d|r · %s · Transit: %s",
			math.floor((prof.landMult or 1) * 100 + 0.5),
			math.floor((prof.waterMult or 0.67) * 100 + 0.5),
			fpCount, avoidStr, gtStr)
	end
	local sLbl = UI:CreateLabel(parent, speedStrip, 0.78, 0.88, 0.96, "GameFontHighlightSmall")
	sLbl:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -148)

	local scroll = UI:CreateScrollFrame(parent, "PluribusNavListScroll", width, math.max(180, height - 172))
	scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, -166)

	local y = -2
	local rowW = width - 26

	if self.selectedCat == "Route" then
		local drDB = (dynRoute and dynRoute.GetDB) and dynRoute:GetDB() or { autoSync = true, includeQuests = false, includeTodos = false }
		local barH = 30
		local bar = CreateFrame("Frame", nil, scroll.content)
		bar:SetSize(rowW, barH)
		bar:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

		local addBothBtn = UI:CreateButton(bar, L("NAV_ROUTE_ADD_BOTH"), 134, 22, function()
			if dynRoute then dynRoute:EnableSources(true, true, true) end
			if onRefresh then onRefresh() end
		end, true)
		addBothBtn:SetPoint("LEFT", bar, "LEFT", 0, 0)

		local addQBtn = UI:CreateButton(bar, L("NAV_ROUTE_ADD_QUESTS"), 80, 22, function()
			if dynRoute then dynRoute:EnableSources(true, nil, true) end
			if onRefresh then onRefresh() end
		end, drDB.includeQuests == true)
		addQBtn:SetPoint("LEFT", addBothBtn, "RIGHT", 5, 0)

		local addTBtn = UI:CreateButton(bar, L("NAV_ROUTE_ADD_TODOS"), 80, 22, function()
			if dynRoute then dynRoute:EnableSources(nil, true, true) end
			if onRefresh then onRefresh() end
		end, drDB.includeTodos == true)
		addTBtn:SetPoint("LEFT", addQBtn, "RIGHT", 5, 0)

		local autoBtn = UI:CreateButton(bar, drDB.autoSync and L("NAV_ROUTE_AUTO_ON") or L("NAV_ROUTE_AUTO_OFF"), 116, 22, function()
			if dynRoute then dynRoute:SetAutoSync(not drDB.autoSync) end
			if onRefresh then onRefresh() end
		end, drDB.autoSync == true)
		autoBtn:SetPoint("LEFT", addTBtn, "RIGHT", 5, 0)

		local clrRouteBtn = UI:CreateButton(bar, L("NAV_ROUTE_CLEAR"), 64, 22, function()
			if dynRoute then dynRoute:ClearRoute() end
			if onRefresh then onRefresh() end
		end)
		clrRouteBtn:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
		y = y - 34

		local activeStop = (dynRoute and dynRoute.GetActiveStop) and dynRoute:GetActiveStop() or nil
		local activeId = activeStop and activeStop.id or nil

		if #dynActive > 0 then
			for idx, stop in ipairs(dynActive) do
				local isCur = (stop.id == activeId)
				local sRef = stop
				local row = UI:CreateListRow(scroll.content, rowW, 38, idx, function()
					if dynRoute then dynRoute:FocusStop(sRef.id) end
					if onRefresh then onRefresh() end
				end)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

				local iconPath = (stop.kind == "todo") and "Interface\\Icons\\INV_Misc_Bag_08"
					or (stop.isTurnIn and "Interface\\GossipFrame\\ActiveQuestIcon" or "Interface\\GossipFrame\\AvailableQuestIcon")
				local br, bg, bb = 0.98, 0.78, 0.24
				if stop.kind == "todo" then
					br, bg, bb = 0.22, 0.74, 0.97
				elseif stop.isTurnIn then
					br, bg, bb = 0.29, 0.87, 0.50
				end
				local badge = UI:CreateIconBadge(row, iconPath, 26, br, bg, bb)
				badge:SetPoint("LEFT", row, "LEFT", 6, 0)

				local kindTag = (stop.kind == "todo") and "|cff38bdf8[To-Do]|r"
					or (stop.isTurnIn and "|cff4ade80[Abgabe]|r" or "|cfffbbf24[Quest]|r")
				local curMark = isCur and "|cff4ade80► |r" or ""
				local l1 = UI:CreateLabel(row, string.format("%s|cff94a3b8#%d|r %s |cffffffff%s|r", curMark, idx, kindTag, tostring(stop.title or "Stopp")))
				l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)
				local detStr = (stop.detail and stop.detail ~= "") and (tostring(stop.detail) .. "  ·  ") or ""
				local l2 = UI:CreateLabel(row, string.format("%s%s (|cfffbbf24%.1f, %.1f|r)", detStr, tostring(stop.zone or "Azeroth"), tonumber(stop.x) or 50, tonumber(stop.y) or 50), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
				l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

				local skipBtn = UI:CreateButton(row, L("NAV_ROUTE_SKIP"), 62, 22, function()
					if dynRoute then dynRoute:SkipStop(sRef.id) end
					if onRefresh then onRefresh() end
				end)
				skipBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

				local navBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 68, 22, function()
					if dynRoute then dynRoute:FocusStop(sRef.id) end
					if onRefresh then onRefresh() end
				end, isCur)
				navBtn:SetPoint("RIGHT", skipBtn, "LEFT", -5, 0)
				y = y - 40
			end
		elseif #dynSkipped == 0 then
			local em = UI:CreateBannerCard(scroll.content, rowW, 56, "Interface\\Icons\\INV_Misc_Map_01",
				"|cff38bdf8" .. L("NAV_CAT_ROUTE") .. "|r",
				L("NAV_ROUTE_EMPTY"),
				0.22, 0.74, 0.97)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			y = y - 62
		end

		if #dynSkipped > 0 then
			y = y - 6
			local skHdr = CreateFrame("Frame", nil, scroll.content)
			skHdr:SetSize(rowW, 24)
			skHdr:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			local skLbl = UI:CreateLabel(skHdr, "|cfffbbf24" .. L("NAV_ROUTE_SKIPPED_HDR", #dynSkipped) .. "|r", 0.98, 0.78, 0.24, "GameFontNormalSmall")
			skLbl:SetPoint("LEFT", skHdr, "LEFT", 4, 0)
			local restAllBtn = UI:CreateButton(skHdr, L("NAV_ROUTE_RESTORE_ALL"), 126, 20, function()
				if dynRoute then dynRoute:RestoreAllSkipped() end
				if onRefresh then onRefresh() end
			end)
			restAllBtn:SetPoint("RIGHT", skHdr, "RIGHT", 0, 0)
			y = y - 26

			for idx, stop in ipairs(dynSkipped) do
				local sRef = stop
				local row = UI:CreateListRow(scroll.content, rowW, 34, idx, function()
					if dynRoute then dynRoute:RestoreStop(sRef.id) end
					if onRefresh then onRefresh() end
				end)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

				local kindTag = (stop.kind == "todo") and "|cff64748b[To-Do]|r" or "|cff64748b[Quest]|r"
				local l1 = UI:CreateLabel(row, string.format("%s |cff94a3b8%s|r  |cff64748b(%s %.1f, %.1f)|r", kindTag, tostring(stop.title), tostring(stop.zone or ""), tonumber(stop.x) or 50, tonumber(stop.y) or 50))
				l1:SetPoint("LEFT", row, "LEFT", 8, 0)

				local restBtn = UI:CreateButton(row, L("NAV_ROUTE_RESTORE"), 72, 22, function()
					if dynRoute then dynRoute:RestoreStop(sRef.id) end
					if onRefresh then onRefresh() end
				end, true)
				restBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				y = y - 36
			end
		end
	elseif self.selectedCat == "Pins" then
		if #pins > 0 then
			local delAll = UI:CreateButton(scroll.content, L("NAV_CLEAR_ALL_PINS"), 126, 22, function()
				PluribusNavigationUI:ClearAllPins()
				if onRefresh then onRefresh() end
			end)
			delAll:SetPoint("TOPRIGHT", scroll.content, "TOPRIGHT", -2, y)
			local hintL = UI:CreateLabel(scroll.content, "|cff94a3b8" .. L("NAV_PINS_HINT") .. "|r", 0.75, 0.85, 0.95, "GameFontHighlightSmall")
			hintL:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 4)
			y = y - 28

			for idx, pin in ipairs(pins) do
				local row = UI:CreateListRow(scroll.content, rowW, 36, idx, function()
					PluribusNavigationUI:SetWaypoint(pin.name, pin.zone, pin.x, pin.y, pin.mapID)
					if onRefresh then onRefresh() end
				end)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

				local badge = UI:CreateIconBadge(row, "Interface\\Icons\\INV_Misc_Map_01", 26, 0.22, 0.74, 0.97)
				badge:SetPoint("LEFT", row, "LEFT", 6, 0)

				local l1 = UI:CreateLabel(row, "|cffffffff" .. pin.name .. "|r")
				l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)
				local l2 = UI:CreateLabel(row, string.format("%s  ·  |cfffbbf24%.1f, %.1f|r", pin.zone, pin.x, pin.y), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
				l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

				local delBtn = UI:CreateButton(row, "X", 24, 22, function()
					PluribusNavigationUI:DeletePin(pin.id)
					if onRefresh then onRefresh() end
				end)
				delBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

				local goBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 82, 22, function()
					PluribusNavigationUI:SetWaypoint(pin.name, pin.zone, pin.x, pin.y, pin.mapID)
					if onRefresh then onRefresh() end
				end, true)
				goBtn:SetPoint("RIGHT", delBtn, "LEFT", -6, 0)
				y = y - 38
			end
		else
			local em = UI:CreateBannerCard(scroll.content, rowW, 56, "Interface\\Icons\\INV_Misc_Map_01",
				"|cff38bdf8" .. L("NAV_CAT_PINS") .. "|r",
				L("NAV_PINS_HINT"),
				0.22, 0.74, 0.97)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			y = y - 62
		end
	elseif self.selectedCat == "Transit" then
		local cfg = (_G.PluribusHive and _G.PluribusHive.GetConfig and _G.PluribusHive:GetConfig()) or {}
		local gtEnabled = (cfg.navUseGuildTransit ~= false)
		local toggleBtn = UI:CreateButton(scroll.content, gtEnabled and "Routing: ON" or "Routing: OFF", 104, 22, function()
			if _G.PluribusHive and _G.PluribusHive.SetConfig then
				_G.PluribusHive:SetConfig("navUseGuildTransit", not gtEnabled)
			end
			if onRefresh then onRefresh() end
		end, gtEnabled)
		toggleBtn:SetPoint("TOPRIGHT", scroll.content, "TOPRIGHT", -2, y)

		local headerDesc = L("NAV_GUILD_TRANSIT_DESC")
		if (gtProviders.skippedInstanced or 0) > 0 then
			headerDesc = headerDesc .. " · |cfffbbf24" .. L("NAV_TRANSIT_INSTANCED", gtProviders.skippedInstanced) .. "|r"
		end
		local tHint = UI:CreateLabel(scroll.content, "|cff94a3b8" .. headerDesc .. "|r", 0.75, 0.85, 0.95, "GameFontHighlightSmall")
		tHint:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 4, y - 3)
		tHint:SetWidth(rowW - 116)
		y = y - 32

		local rIdx = 0
		for _, m in ipairs(gtProviders.mages or {}) do
			rIdx = rIdx + 1
			local portalNames = {}
			for _, p in ipairs(m.portals or {}) do
				table.insert(portalNames, p.destLabel)
			end
			local pList = table.concat(portalNames, ", ")
			local row = UI:CreateListRow(scroll.content, rowW, 38, rIdx, function()
				PluribusNavigationUI:SetWaypoint(m.name .. " (Mage)", m.zone, m.x, m.y)
				if onRefresh then onRefresh() end
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local cIcon = UI:CreateClassIcon(row, "MAGE", 26)
			cIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

			local l1 = UI:CreateLabel(row, string.format("|cff69ccf0%s|r  |cff60a5fa[%s]|r  |cff94a3b8Lv%d · %s|r", m.name, L("NAV_LEG_PORTAL"), m.level or 60, m.zone or "Azeroth"))
			l1:SetPoint("TOPLEFT", cIcon, "TOPRIGHT", 8, -1)
			local l2 = UI:CreateLabel(row, string.format("Portals: |cffffffff%s|r  ·  ~%ds%s", pList, m.estimatedCostSec or 45, m.hasLiveGPS and " (Hive GPS)" or ""), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", cIcon, "BOTTOMRIGHT", 8, 1)

			local wBtn = UI:CreateButton(row, L("NAV_ASK_WHISPER"), 72, 22, function()
				if _G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.OpenWhisperPrompt then
					_G.PluribusHiveGuildTransit:OpenWhisperPrompt(m.name, "portal", portalNames[1] or "Capital")
				end
			end, true)
			wBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

			local navBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 74, 22, function()
				PluribusNavigationUI:SetWaypoint(m.name .. " (Mage)", m.zone, m.x, m.y)
				if onRefresh then onRefresh() end
			end)
			navBtn:SetPoint("RIGHT", wBtn, "LEFT", -6, 0)
			y = y - 40
		end

		for _, wl in ipairs(gtProviders.warlocks or {}) do
			rIdx = rIdx + 1
			local row = UI:CreateListRow(scroll.content, rowW, 38, rIdx, function()
				PluribusNavigationUI:SetWaypoint(wl.name .. " (Summon)", wl.zone, wl.x, wl.y)
				if onRefresh then onRefresh() end
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local cIcon = UI:CreateClassIcon(row, "WARLOCK", 26)
			cIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

			local l1 = UI:CreateLabel(row, string.format("|cff9482c9%s|r  |cffc084fc[%s]|r  |cff94a3b8Lv%d · %s|r", wl.name, L("NAV_LEG_SUMMON"), wl.level or 60, wl.zone or "Azeroth"))
			l1:SetPoint("TOPLEFT", cIcon, "TOPRIGHT", 8, -1)
			local l2 = UI:CreateLabel(row, string.format("~%ds (incl. +%ds 2-helper buffer · %d guild in zone)%s", wl.estimatedCostSec or 155, wl.helperPenaltySec or 95, wl.nearbyHelpers or 0, wl.hasLiveGPS and " · GPS" or ""), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", cIcon, "BOTTOMRIGHT", 8, 1)

			local wBtn = UI:CreateButton(row, L("NAV_ASK_WHISPER"), 72, 22, function()
				if _G.PluribusHiveGuildTransit and _G.PluribusHiveGuildTransit.OpenWhisperPrompt then
					_G.PluribusHiveGuildTransit:OpenWhisperPrompt(wl.name, "summon", wl.zone)
				end
			end, true)
			wBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)

			local navBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 74, 22, function()
				PluribusNavigationUI:SetWaypoint(wl.name .. " (Summon)", wl.zone, wl.x, wl.y)
				if onRefresh then onRefresh() end
			end)
			navBtn:SetPoint("RIGHT", wBtn, "LEFT", -6, 0)
			y = y - 40
		end

		if rIdx == 0 then
			local em = UI:CreateBannerCard(scroll.content, rowW, 56, "Interface\\Icons\\Spell_Arcane_PortalStormWind",
				"|cff60a5fa" .. L("NAV_CAT_TRANSIT") .. "|r",
				L("NAV_TRANSIT_EMPTY"),
				0.38, 0.72, 1.00)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)
			y = y - 62
		end
	elseif self.selectedCat == "Guild" then
		local members = (_G.PluribusHive and _G.PluribusHive:GetOnlineMembers()) or {}
		local idx = 0
		for _, m in ipairs(members) do
			if not m.isSelf then
				idx = idx + 1
				local row = UI:CreateListRow(scroll.content, rowW, 34, idx, function()
					PluribusNavigationUI:SetWaypoint(m.name .. " (Guild)", m.zone or "Azeroth", (m.x or 0.5) * 100, (m.y or 0.5) * 100, m.mapID)
					if onRefresh then onRefresh() end
				end)
				row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

				local cIcon = UI:CreateClassIcon(row, m.class, 24)
				cIcon:SetPoint("LEFT", row, "LEFT", 6, 0)

				local _, _, _, hex = UI:GetClassColor(m.class)
				local l1 = UI:CreateLabel(row, string.format("%s%s|r  |cff94a3b8Lv%d · %s|r", hex, m.name, m.level or 60, m.zone or "Azeroth"))
				l1:SetPoint("LEFT", cIcon, "RIGHT", 8, 0)

				local goBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 86, 22, function()
					PluribusNavigationUI:SetWaypoint(m.name .. " (Guild)", m.zone or "Azeroth", (m.x or 0.5) * 100, (m.y or 0.5) * 100, m.mapID)
					if onRefresh then onRefresh() end
				end, true)
				goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
				y = y - 36
			end
		end
		if idx == 0 then
			local em = UI:CreateLabel(scroll.content, "No online guildmates with GPS pings right now.", 0.68, 0.78, 0.88)
			em:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 6, -8)
		end
	else
		local list = self.DESTINATIONS[self.selectedCat] or self.DESTINATIONS.Raids
		for idx, wp in ipairs(list) do
			local row = UI:CreateListRow(scroll.content, rowW, 36, idx, function()
				PluribusNavigationUI:SetWaypoint(wp.name, wp.zone, wp.x, wp.y)
				if onRefresh then onRefresh() end
			end)
			row:SetPoint("TOPLEFT", scroll.content, "TOPLEFT", 0, y)

			local badge = UI:CreateIconBadge(row, wp.icon or "Interface\\Icons\\INV_Misc_Map_01", 26, 0.22, 0.74, 0.97)
			badge:SetPoint("LEFT", row, "LEFT", 6, 0)

			local l1 = UI:CreateLabel(row, "|cffffffff" .. wp.name .. "|r")
			l1:SetPoint("TOPLEFT", badge, "TOPRIGHT", 8, -1)
			local l2 = UI:CreateLabel(row, string.format("%s  ·  |cfffbbf24%.1f, %.1f|r", wp.zone, wp.x, wp.y), 0.72, 0.82, 0.92, "GameFontHighlightSmall")
			l2:SetPoint("BOTTOMLEFT", badge, "BOTTOMRIGHT", 8, 1)

			local goBtn = UI:CreateButton(row, L("TODO_NAV_ROUTE"), 86, 22, function()
				PluribusNavigationUI:SetWaypoint(wp.name, wp.zone, wp.x, wp.y)
				if onRefresh then onRefresh() end
			end, true)
			goBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
			y = y - 38
		end
	end
	scroll.content:SetHeight(math.max(180, math.abs(y) + 12))
end

function PluribusNavigationUI:Toggle()
	if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
		_G.PluribusMainFrame:OpenToTab("Navigation")
		return
	end
	if not self.mainWindow then self:CreateMainWindow() end
	self.mainWindow:SetShown(not self.mainWindow:IsShown())
	if self.mainWindow:IsShown() then self:Refresh() end
end

function PluribusNavigationUI:CreateMainWindow()
	local frame = PluribusUIFramework:CreateFrame("PluribusNavigationMainWindow", UIParent, 660, 460, "Pluribus Navigation", "Smart Pathfinder & Map Pins")
	frame:SetPoint("CENTER")
	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -40)
	frame.body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
	self.mainWindow = frame
	self:Refresh()
end

function PluribusNavigationUI:Refresh()
	if not self.mainWindow then return end
	PluribusUIFramework:ClearContainer(self.mainWindow.body)
	self:RenderEmbedded(self.mainWindow.body, 636, 412, function() PluribusNavigationUI:Refresh() end)
end

function PluribusNavigationUI:Initialize()
	self:AttachToWorldMap()
	self:EnsureMinimapRouteLayer()
	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("HIVE_ROUTE_CHANGED", function()
			PluribusNavigationUI:RefreshWorldMapRoutePath()
			PluribusNavigationUI:UpdateMinimapRoutePath()
		end)
		_G.PluribusMessaging:Subscribe("HIVE_DYNAMIC_ROUTE_CHANGED", function()
			PluribusNavigationUI:RefreshWorldMapRoutePath()
			if PluribusNavigationUI.mainWindow and PluribusNavigationUI.mainWindow:IsShown() then
				PluribusNavigationUI:Refresh()
			end
		end)
	end
	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "PLAYER_ENTERING_WORLD")
	pcall(f.RegisterEvent, f, "WORLD_MAP_UPDATE")
	pcall(f.RegisterEvent, f, "ZONE_CHANGED_NEW_AREA")
	f:SetScript("OnEvent", function(_, ev)
		if ev == "PLAYER_ENTERING_WORLD" then
			PluribusNavigationUI:AttachToWorldMap()
			PluribusNavigationUI:EnsureMinimapRouteLayer()
		elseif ev == "WORLD_MAP_UPDATE" or ev == "ZONE_CHANGED_NEW_AREA" then
			PluribusNavigationUI:RefreshWorldMapPins()
			PluribusNavigationUI:UpdateMinimapRoutePath()
		end
	end)
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Smart Pathfinder, Compass HUD, Map/Minimap Route Overlay & Pins initialized (/nav, /way)", "Navigation")
	end
end

return PluribusNavigationUI
