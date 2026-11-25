-- PluribusHive Dynamic Auto-Updating Quest & To-Do Route Engine (Warcraft Forever 1.60.1)
-- Combines active WoW Quest Log entries and Pluribus To-Do / Shopping List targets into a single
-- auto-updating, distance-optimized multi-stop route with temporary stop skipping & 1-click restore.

PluribusHiveDynamicRoute = {
	initialized = false,
	_syncPending = false,
	_lastSyncAt = 0,
}
_G.PluribusHiveDynamicRoute = PluribusHiveDynamicRoute

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

local function CanonicalZone(z)
	if not z or z == "" then return "" end
	if _G.PluribusHivePathfinder and _G.PluribusHivePathfinder.CanonicalZone then
		return _G.PluribusHivePathfinder:CanonicalZone(z)
	end
	return tostring(z)
end

local function GetPlayerLocation()
	local zone = CanonicalZone((GetRealZoneText and GetRealZoneText()) or "Azeroth")
	local px, py = 50, 50
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			px, py = ux * 100, uy * 100
		end
	end
	return zone, px, py
end

local function GetZoneFallbackCoords(zoneName)
	local cz = CanonicalZone(zoneName)
	local pf = _G.PluribusHivePathfinder
	if pf and pf.NODES then
		for _, n in pairs(pf.NODES) do
			if n.zone and n.zone:lower() == cz:lower() then
				return n.zone, n.x or 50, n.y or 50
			end
		end
	end
	return (cz ~= "" and cz or "Azeroth"), 50, 50
end

local function GetCapitalAHCoords()
	local fac = UnitFactionGroup and select(1, pcall(UnitFactionGroup, "player")) and UnitFactionGroup("player") or "Alliance"
	if fac == "Horde" then
		return "Orgrimmar", 55.6, 64.0
	end
	return "Stormwind City", 53.6, 59.8
end

function PluribusHiveDynamicRoute:GetDB()
	local root = (_G.PluribusHive and _G.PluribusHive.GetDB and _G.PluribusHive:GetDB()) or self._fallbackDB
	if not root then
		self._fallbackDB = {}
		root = self._fallbackDB
	end
	root.dynamicRoute = root.dynamicRoute or {
		autoSync = true,
		includeQuests = false,
		includeTodos = false,
		stops = {},
		manualStops = {},
		skippedIds = {},
		activeStopId = nil,
		updatedAt = 0,
	}
	local dr = root.dynamicRoute
	dr.stops = dr.stops or {}
	dr.manualStops = dr.manualStops or {}
	dr.skippedIds = dr.skippedIds or {}
	if dr.autoSync == nil then dr.autoSync = true end
	return dr
end

-- ============================================================================
-- DISTANCE & NEAREST-NEIGHBOR + 2-OPT STOP ORDERING
-- ============================================================================
local function EstimateStopDistance(z1, x1, y1, z2, x2, y2)
	local c1 = CanonicalZone(z1):lower()
	local c2 = CanonicalZone(z2):lower()
	local dx = (tonumber(x2) or 50) - (tonumber(x1) or 50)
	local dy = (tonumber(y2) or 50) - (tonumber(y1) or 50)
	local localYds = math.sqrt(dx * dx + dy * dy) * 28
	if c1 == c2 then
		return localYds
	end
	local pf = _G.PluribusHivePathfinder
	if pf and pf.GetZoneContinent then
		local cont1 = pf:GetZoneContinent(z1)
		local cont2 = pf:GetZoneContinent(z2)
		if cont1 and cont2 and cont1 ~= cont2 then
			return 4500 + localYds
		end
	end
	return 1600 + localYds
end

function PluribusHiveDynamicRoute:OptimizeStopOrder(stops, startZone, startX, startY)
	if not stops or #stops <= 1 then return stops or {} end
	local remaining = {}
	for i, s in ipairs(stops) do remaining[i] = s end

	local ordered = {}
	local curZ, curX, curY = startZone or "Azeroth", startX or 50, startY or 50
	while #remaining > 0 do
		local bestIdx, bestDist = 1, 9999999
		for i, s in ipairs(remaining) do
			local d = EstimateStopDistance(curZ, curX, curY, s.zone, s.x, s.y)
			-- Slightly favor ready-to-turn-in quests in the same zone
			if s.isTurnIn and CanonicalZone(s.zone):lower() == CanonicalZone(curZ):lower() then
				d = d * 0.88
			end
			if d < bestDist then
				bestDist = d
				bestIdx = i
			end
		end
		local chosen = table.remove(remaining, bestIdx)
		table.insert(ordered, chosen)
		curZ, curX, curY = chosen.zone, chosen.x, chosen.y
	end

	-- Lightweight 2-Opt pass to untangle crossings cleanly (O(N^2), N <= 40)
	local n = #ordered
	if n >= 3 then
		local function PathCost(arr)
			local cost = EstimateStopDistance(startZone, startX, startY, arr[1].zone, arr[1].x, arr[1].y)
			for i = 1, #arr - 1 do
				cost = cost + EstimateStopDistance(arr[i].zone, arr[i].x, arr[i].y, arr[i + 1].zone, arr[i + 1].x, arr[i + 1].y)
			end
			return cost
		end
		local improved = true
		local passes = 0
		while improved and passes < 6 do
			improved = false
			passes = passes + 1
			local bestCost = PathCost(ordered)
			for i = 1, n - 1 do
				for k = i + 1, n do
					-- Reverse slice [i..k]
					local a, b = i, k
					while a < b do
						ordered[a], ordered[b] = ordered[b], ordered[a]
						a = a + 1
						b = b - 1
					end
					local newCost = PathCost(ordered)
					if newCost + 5 < bestCost then
						bestCost = newCost
						improved = true
					else
						-- Revert slice
						local ra, rb = i, k
						while ra < rb do
							ordered[ra], ordered[rb] = ordered[rb], ordered[ra]
							ra = ra + 1
							rb = rb - 1
						end
					end
				end
			end
		end
	end

	return ordered
end

-- ============================================================================
-- COLLECT LIVE QUEST LOG & TO-DO STOPS
-- ============================================================================
local function LookupQuestCoords(questID, questTitle, fallbackZone, isComplete)
	-- 1. Learned local/guild Quest-NPC index (from PluribusHiveTooltips passive learning)
	if _G.PluribusHiveTooltips and _G.PluribusHiveTooltips.GetLearnedQuestCoords then
		local lz, lx, ly = _G.PluribusHiveTooltips:GetLearnedQuestCoords(questID, questTitle, isComplete)
		if lz and lx and ly then
			return CanonicalZone(lz), lx, ly
		end
	end

	-- 2. Optional QuestieDB / PluribusQuestIntegration coordinates
	if _G.PluribusQuestIntegration and _G.PluribusQuestIntegration.GetObjectiveLocations and questID then
		local ok, locs = pcall(_G.PluribusQuestIntegration.GetObjectiveLocations, _G.PluribusQuestIntegration, questID)
		if ok and type(locs) == "table" and locs[1] and locs[1].zone then
			return CanonicalZone(locs[1].zone), tonumber(locs[1].x) or 50, tonumber(locs[1].y) or 50
		end
	end

	-- 3. Native Classic Quest POI helper if available
	if questID and _G.C_QuestLog and _G.C_QuestLog.GetNextWaypoint then
		local ok, mapID, wx, wy = pcall(_G.C_QuestLog.GetNextWaypoint, questID)
		if ok and mapID and wx and wy and (wx > 0 or wy > 0) then
			local zName = fallbackZone
			if C_Map and C_Map.GetMapInfo then
				local okI, info = pcall(C_Map.GetMapInfo, mapID)
				if okI and info and info.name then zName = info.name end
			end
			return CanonicalZone(zName), wx * 100, wy * 100, mapID
		end
	end

	-- 4. Zone hub fallback based on Quest Log header zone
	return GetZoneFallbackCoords(fallbackZone)
end

function PluribusHiveDynamicRoute:CollectActiveQuestStops()
	local stops = {}
	if not _G.PluribusUtils or not _G.PluribusUtils.GetQuestLogCount then return stops end
	local count = _G.PluribusUtils:GetQuestLogCount()
	local curZone = CanonicalZone((GetRealZoneText and GetRealZoneText()) or "Azeroth")
	local headerZone = curZone

	for i = 1, count do
		local title, level, isHeader, questID, isComplete = _G.PluribusUtils:GetQuestLogEntry(i)
		if title then
			if isHeader then
				headerZone = CanonicalZone(title)
			else
				local qid = tonumber(questID) or 0
				local rawObjs = (qid > 0) and _G.PluribusUtils:GetQuestObjectives(qid) or {}
				local doneObjs, totalObjs = 0, #rawObjs
				local firstOpenText = nil
				for _, o in ipairs(rawObjs) do
					if o.finished then
						doneObjs = doneObjs + 1
					elseif not firstOpenText and o.text then
						firstOpenText = tostring(o.text)
					end
				end
				local readyTurnIn = (isComplete == true or isComplete == 1) or (totalObjs > 0 and doneObjs >= totalObjs)
				local z, x, y, mapID = LookupQuestCoords(qid, title, headerZone ~= "" and headerZone or curZone, readyTurnIn)
				local detail
				if readyTurnIn then
					detail = "Abgabebereit · " .. tostring(z)
				elseif firstOpenText then
					detail = firstOpenText
				elseif totalObjs > 0 then
					detail = string.format("%d/%d Ziele · %s", doneObjs, totalObjs, tostring(z))
				else
					detail = tostring(z)
				end

				local stableId = (qid > 0) and ("quest:" .. tostring(qid)) or ("questname:" .. tostring(title):lower())
				table.insert(stops, {
					id = stableId,
					kind = "quest",
					questID = qid,
					level = tonumber(level) or 0,
					title = title,
					detail = detail,
					zone = z,
					x = x,
					y = y,
					mapID = mapID or 0,
					isTurnIn = readyTurnIn,
				})
			end
		end
	end
	return stops
end

function PluribusHiveDynamicRoute:CollectActiveTodoStops()
	local stops = {}
	local profs = _G.PluribusHiveProfessions
	if not profs or not profs.GetAggregatedShoppingMaterials then return stops end

	local ok, matMap = pcall(profs.GetAggregatedShoppingMaterials, profs)
	if not ok or type(matMap) ~= "table" then return stops end

	for _, m in pairs(matMap) do
		local itemID = tonumber(m.itemID)
		if itemID and itemID > 0 then
			local qty = tonumber(m.qty) or 1
			local owned = (profs.GetOwnedCount and profs:GetOwnedCount(itemID)) or 0
			if owned < qty then
				local name = _G.PluribusUtils and select(1, _G.PluribusUtils:GetItemInfo(itemID))
				local displayName = name or ("Item #" .. tostring(itemID))
				local mode = (profs.GetItemTodoMode and profs:GetItemTodoMode(itemID)) or "FARM"
				local z, x, y, detail
				if mode == "BUY" then
					z, x, y = GetCapitalAHCoords()
					detail = string.format("AH Kaufen (%d/%d) · %s", owned, qty, z)
				else
					local route = _G.PluribusHiveCompute and _G.PluribusHiveCompute.GetFarmRouteForItem
						and _G.PluribusHiveCompute:GetFarmRouteForItem(itemID, displayName)
					if route and route.zone then
						z = CanonicalZone(route.zone)
						x = tonumber(route.x) or 50
						y = tonumber(route.y) or 50
						detail = string.format("Farmen (%d/%d) · %s", owned, qty, tostring(route.source or z))
					else
						z, x, y = GetZoneFallbackCoords((GetRealZoneText and GetRealZoneText()) or "Azeroth")
						detail = string.format("Farmen (%d/%d)", owned, qty)
					end
				end
				table.insert(stops, {
					id = "todo:" .. tostring(itemID),
					kind = "todo",
					itemID = itemID,
					todoMode = mode,
					owned = owned,
					qty = qty,
					title = displayName,
					detail = detail,
					zone = z,
					x = x,
					y = y,
					mapID = 0,
				})
			end
		end
	end
	return stops
end

-- ============================================================================
-- CORE ROUTE OPERATIONS (BUILD, AUTO-SYNC, SKIP, RESTORE, FOCUS, CLEAR)
-- ============================================================================
function PluribusHiveDynamicRoute:GetActiveAndSkipped()
	local dr = self:GetDB()
	local active, skipped = {}, {}
	for _, s in ipairs(dr.stops or {}) do
		if dr.skippedIds[s.id] then
			table.insert(skipped, s)
		else
			table.insert(active, s)
		end
	end
	return active, skipped
end

function PluribusHiveDynamicRoute:GetActiveStop()
	local dr = self:GetDB()
	local active = self:GetActiveAndSkipped()
	if #active == 0 then return nil, 0, 0 end
	for idx, s in ipairs(active) do
		if s.id == dr.activeStopId then
			return s, idx, #active
		end
	end
	dr.activeStopId = active[1].id
	return active[1], 1, #active
end

function PluribusHiveDynamicRoute:NavigateToActiveStop(silent)
	local stop, idx, total = self:GetActiveStop()
	local nav = _G.PluribusNavigationUI
	if not stop then
		if nav and nav.activeWaypoint and nav.activeWaypoint._fromDynamicRoute then
			nav:ClearWaypoint()
		end
		return nil
	end
	if nav and nav.SetWaypoint then
		local prefix = stop.kind == "quest" and (stop.isTurnIn and "[Abgabe] " or "[Quest] ")
			or (stop.kind == "todo" and "[To-Do] " or "[Route] ")
		nav:SetWaypoint(prefix .. tostring(stop.title), stop.zone, stop.x, stop.y, stop.mapID, {
			fromDynamicRoute = true,
			stopId = stop.id,
			stopIndex = idx,
			stopTotal = total,
			silent = silent == true,
		})
	end
	return stop
end

function PluribusHiveDynamicRoute:PublishChanged()
	if _G.PluribusMessaging and _G.PluribusMessaging.Publish then
		pcall(function() _G.PluribusMessaging:Publish("HIVE_DYNAMIC_ROUTE_CHANGED") end)
	end
	if _G.PluribusNavigationUI then
		if _G.PluribusNavigationUI.RefreshWorldMapRoutePath then
			_G.PluribusNavigationUI:RefreshWorldMapRoutePath()
		end
		if _G.PluribusNavigationUI.mainWindow and _G.PluribusNavigationUI.mainWindow:IsShown() then
			_G.PluribusNavigationUI:Refresh()
		end
	end
end

function PluribusHiveDynamicRoute:SyncFromSources(reason, silent)
	local dr = self:GetDB()
	local prevActiveId = dr.activeStopId
	local merged = {}
	local seen = {}

	if dr.includeQuests then
		for _, qs in ipairs(self:CollectActiveQuestStops()) do
			if not seen[qs.id] then
				seen[qs.id] = true
				table.insert(merged, qs)
			end
		end
	end
	if dr.includeTodos then
		for _, ts in ipairs(self:CollectActiveTodoStops()) do
			if not seen[ts.id] then
				seen[ts.id] = true
				table.insert(merged, ts)
			end
		end
	end
	for _, ms in ipairs(dr.manualStops or {}) do
		if ms and ms.id and not seen[ms.id] then
			seen[ms.id] = true
			table.insert(merged, ms)
		end
	end

	-- Prune skippedIds for stops that no longer exist (completed naturally!)
	for sid in pairs(dr.skippedIds) do
		if not seen[sid] then
			dr.skippedIds[sid] = nil
		end
	end

	-- Split active vs skipped and optimize only the active ones
	local activeRaw, skippedRaw = {}, {}
	for _, s in ipairs(merged) do
		if dr.skippedIds[s.id] then
			s.skipped = true
			table.insert(skippedRaw, s)
		else
			s.skipped = false
			table.insert(activeRaw, s)
		end
	end

	local pz, px, py = GetPlayerLocation()
	local orderedActive = self:OptimizeStopOrder(activeRaw, pz, px, py)

	-- Rebuild dr.stops with ordered active stops first, skipped stops after
	local finalStops = {}
	for _, s in ipairs(orderedActive) do table.insert(finalStops, s) end
	for _, s in ipairs(skippedRaw) do table.insert(finalStops, s) end
	dr.stops = finalStops
	dr.updatedAt = time()

	-- Preserve active stop if it still exists and isn't skipped; otherwise advance to next stop!
	local stillActive = false
	for _, s in ipairs(orderedActive) do
		if s.id == prevActiveId then
			stillActive = true
			break
		end
	end
	if not stillActive then
		dr.activeStopId = orderedActive[1] and orderedActive[1].id or nil
	end

	-- Update active navigation target if route is running or active stop changed
	local nav = _G.PluribusNavigationUI
	local navUsingRoute = nav and nav.activeWaypoint and nav.activeWaypoint._fromDynamicRoute
	if (not silent) or navUsingRoute or (prevActiveId and prevActiveId ~= dr.activeStopId) then
		if #orderedActive > 0 then
			self:NavigateToActiveStop(silent)
		elseif navUsingRoute then
			nav:ClearWaypoint()
			if _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification("|cff4ade80Alle aktiven Routen-Stopps abgeschlossen!|r", 3.5)
			end
		end
	end

	self:PublishChanged()
	return #orderedActive, #skippedRaw
end

function PluribusHiveDynamicRoute:EnableSources(quests, todos, autoNavigate)
	local dr = self:GetDB()
	if quests ~= nil then dr.includeQuests = quests == true end
	if todos ~= nil then dr.includeTodos = todos == true end
	dr.autoSync = true
	local activeN, skippedN = self:SyncFromSources("user_add", not (autoNavigate ~= false))
	if _G.PluribusUIFramework then
		_G.PluribusUIFramework:ShowNotification(
			string.format("|cff38bdf8Dynamische Route aktualisiert:|r %d aktive Stopps%s",
				activeN, skippedN > 0 and (" (" .. skippedN .. " übersprungen)") or ""),
			3.0)
	end
	return activeN, skippedN
end

function PluribusHiveDynamicRoute:AddManualStop(title, zone, x, y, mapID)
	local dr = self:GetDB()
	local id = "custom:" .. tostring(time()) .. "_" .. tostring(math.random(100, 999))
	table.insert(dr.manualStops, {
		id = id,
		kind = "custom",
		title = tostring(title or "Custom Stop"),
		detail = string.format("%s (%.1f, %.1f)", tostring(zone or "Azeroth"), tonumber(x) or 50, tonumber(y) or 50),
		zone = CanonicalZone(zone or "Azeroth"),
		x = tonumber(x) or 50,
		y = tonumber(y) or 50,
		mapID = tonumber(mapID) or 0,
	})
	self:SyncFromSources("manual_add", false)
	return id
end

function PluribusHiveDynamicRoute:RemoveManualStop(stopId)
	local dr = self:GetDB()
	for i = #dr.manualStops, 1, -1 do
		if dr.manualStops[i].id == stopId then
			table.remove(dr.manualStops, i)
		end
	end
	dr.skippedIds[stopId] = nil
	self:SyncFromSources("manual_remove", true)
end

-- Temporarily skip a stop ("vorerst überspringen") and immediately advance to the next stop!
function PluribusHiveDynamicRoute:SkipStop(stopId)
	local dr = self:GetDB()
	if not stopId then return false end
	local skippedTitle = nil
	for _, s in ipairs(dr.stops or {}) do
		if s.id == stopId then
			skippedTitle = s.title
			break
		end
	end
	dr.skippedIds[stopId] = true
	if dr.activeStopId == stopId then
		dr.activeStopId = nil
	end
	local activeN = self:SyncFromSources("skip", false)
	if _G.PluribusUIFramework and skippedTitle then
		_G.PluribusUIFramework:ShowNotification(
			string.format("|cfffbbf24Stopp vorerst übersprungen:|r %s (%d verbleibend)", tostring(skippedTitle), activeN),
			2.8)
	end
	return true
end

function PluribusHiveDynamicRoute:SkipActiveStop()
	local active = self:GetActiveStop()
	if not active then return false end
	return self:SkipStop(active.id)
end

function PluribusHiveDynamicRoute:RestoreStop(stopId)
	local dr = self:GetDB()
	if not stopId then return false end
	dr.skippedIds[stopId] = nil
	self:SyncFromSources("restore", false)
	return true
end

function PluribusHiveDynamicRoute:RestoreAllSkipped()
	local dr = self:GetDB()
	dr.skippedIds = {}
	self:SyncFromSources("restore_all", false)
end

function PluribusHiveDynamicRoute:FocusStop(stopId)
	local dr = self:GetDB()
	if not stopId then return false end
	dr.skippedIds[stopId] = nil
	dr.activeStopId = stopId
	self:NavigateToActiveStop(false)
	self:PublishChanged()
	return true
end

function PluribusHiveDynamicRoute:SetAutoSync(enabled)
	local dr = self:GetDB()
	dr.autoSync = enabled == true
	if dr.autoSync and (dr.includeQuests or dr.includeTodos) then
		self:SyncFromSources("autosync_toggled", true)
	else
		self:PublishChanged()
	end
end

function PluribusHiveDynamicRoute:ClearRoute()
	local dr = self:GetDB()
	dr.includeQuests = false
	dr.includeTodos = false
	dr.stops = {}
	dr.manualStops = {}
	dr.skippedIds = {}
	dr.activeStopId = nil
	local nav = _G.PluribusNavigationUI
	if nav and nav.activeWaypoint and nav.activeWaypoint._fromDynamicRoute then
		nav:ClearWaypoint()
	end
	self:PublishChanged()
end

function PluribusHiveDynamicRoute:ScheduleAutoSync(reason)
	local dr = self:GetDB()
	if not dr.autoSync then return end
	if not dr.includeQuests and not dr.includeTodos then return end
	if self._syncPending then return end
	self._syncPending = true
	local run = function()
		PluribusHiveDynamicRoute._syncPending = false
		PluribusHiveDynamicRoute:SyncFromSources(reason or "auto", true)
	end
	if C_Timer and C_Timer.After then
		C_Timer.After(0.35, run)
	else
		run()
	end
end

function PluribusHiveDynamicRoute:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:GetDB()

	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("HIVE_TODO_CHANGED", function()
			PluribusHiveDynamicRoute:ScheduleAutoSync("todo_changed")
		end)
	end

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"PLAYER_ENTERING_WORLD",
		"QUEST_LOG_UPDATE",
		"QUEST_ACCEPTED",
		"QUEST_REMOVED",
		"QUEST_WATCH_UPDATE",
		"QUEST_TURNED_IN",
		"BAG_UPDATE_DELAYED",
		"ZONE_CHANGED_NEW_AREA",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, ev)
		if ev == "PLAYER_ENTERING_WORLD" then
			local dr = PluribusHiveDynamicRoute:GetDB()
			if dr.autoSync and (dr.includeQuests or dr.includeTodos) then
				PluribusHiveDynamicRoute:ScheduleAutoSync("login")
			end
		else
			PluribusHiveDynamicRoute:ScheduleAutoSync(ev)
		end
	end)
end

return PluribusHiveDynamicRoute
