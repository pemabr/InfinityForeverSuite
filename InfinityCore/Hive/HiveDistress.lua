-- InfinityHive Open-World Distress, Rare Spotting, Shared Nodes & Quest Overlap
-- Strictly NEVER triggers distress warnings inside instances, raids, BGs, or arenas
-- Warns nearby guildmates only when close enough to arrive and help in time

InfinityHiveDistress = {
	initialized = false,
	lastSOSSent = 0,
	lastSOSBySender = {},
	lastRareSeen = {},
	lastQuestBroadcast = 0,
}
_G.InfinityHiveDistress = InfinityHiveDistress

local function IsInOpenWorld()
	if IsInInstance then
		local inInstance, instanceType = IsInInstance()
		if inInstance or (instanceType and instanceType ~= "none") then
			return false
		end
	end
	return true
end

function InfinityHiveDistress:BroadcastSOS(manual)
	local cfg = InfinityHive:GetConfig()
	if not cfg.shareDistress then return false end
	if not IsInOpenWorld() then return false end

	local now = GetTime()
	if not manual and (now - self.lastSOSSent) < 35 then
		return false
	end

	local hp = UnitHealth and UnitHealth("player") or 0
	local hpMax = UnitHealthMax and UnitHealthMax("player") or 1
	if InfinityUtils:IsSecret(hp) or InfinityUtils:IsSecret(hpMax) or hpMax <= 0 then
		return false
	end
	local hpPct = math.floor((hp / hpMax) * 100)
	local px, py, mapID = InfinityUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local subzone = (GetSubZoneText and GetSubZoneText()) or ""
	local attacker = "Danger"
	if UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") then
		local tName = UnitName("target")
		if tName and not InfinityUtils:IsSecret(tName) then
			attacker = tName
		end
	end

	self.lastSOSSent = now
	local payload = string.format("%s|%d|%s|%s|%.4f|%.4f|%d|%s",
		InfinityHive:GetPlayerClass(),
		mapID or 0,
		zone:gsub("|", " "),
		subzone:gsub("|", " "),
		px or 0,
		py or 0,
		hpPct,
		attacker:gsub("|", " ")
	)
	InfinityHive:Send("SOS", payload, "GUILD", nil, true)
	InfinityHive:AddFeedEvent("SOS", "Sent distress ping in " .. zone .. string.format(" (%.1f, %.1f)", (px or 0) * 100, (py or 0) * 100))
	return true
end

function InfinityHiveDistress:HandleIncomingSOS(sender, body)
	local cfg = InfinityHive:GetConfig()
	if not cfg.showDistressAlerts then return end
	if not IsInOpenWorld() then return end

	local now = GetTime()
	if self.lastSOSBySender[sender] and (now - self.lastSOSBySender[sender]) < 30 then
		return
	end

	local cls, mapIDStr, zone, subzone, xStr, yStr, hpStr, attacker =
		body:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
	local mapID = tonumber(mapIDStr) or 0
	local tx, ty = tonumber(xStr) or 0, tonumber(yStr) or 0
	local hpPct = tonumber(hpStr) or 25

	-- Check if we are in the SAME zone/map AND close enough to reach them in time!
	local mx, my, myMapID = InfinityUtils:GetUnitMapPosition("player")
	local myZone = (GetRealZoneText and GetRealZoneText()) or ""
	local sameArea = (mapID > 0 and myMapID and mapID == myMapID) or (zone ~= "" and zone == myZone)
	if not sameArea then return end

	local dist = 0
	if tx > 0 and ty > 0 and mx and my and (mx > 0 or my > 0) then
		local dx, dy = tx - mx, ty - my
		dist = math.sqrt(dx * dx + dy * dy)
		if dist > (cfg.distressMaxDistance or 0.18) then
			return -- Too far away to save them in time — do not irritate the player
		end
	end

	self.lastSOSBySender[sender] = now
	local etaSec = math.max(5, math.floor(dist * 240))
	local locText = string.format("%s (%.1f, %.1f)", (subzone ~= "" and subzone or zone), tx * 100, ty * 100)

	InfinityHive:AddFeedEvent("SOS", string.format("%s needs help (%d%% HP vs %s) — ~%ds away at %s", sender, hpPct, attacker or "Mob", etaSec, locText))

	if _G.InfinityHiveUI and _G.InfinityHiveUI.ShowToast then
		_G.InfinityHiveUI:ShowToast({
			kind = "SOS",
			title = string.format("Guildmate in Danger: %s (%d%% HP)", sender, hpPct),
			body = string.format("Fighting %s · %s · ~%ds away", attacker or "Enemy", locText, etaSec),
			color = { 0.94, 0.27, 0.27 },
			duration = 14,
			action1 = {
				label = "Set Waypoint",
				onClick = function()
					InfinityHiveDistress:SetRescueWaypoint(mapID, tx, ty, sender .. " (SOS)")
				end,
			},
			action2 = {
				label = "On my way!",
				onClick = function()
					if SendChatMessage then
						pcall(SendChatMessage, "On my way to help! Hold on!", "WHISPER", nil, sender)
					end
					InfinityHiveDistress:SetRescueWaypoint(mapID, tx, ty, sender .. " (SOS)")
				end,
			},
		})
	end
end

function InfinityHiveDistress:SetRescueWaypoint(mapID, x, y, title)
	if mapID and mapID > 0 and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
		pcall(function()
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			end
		end)
	end
	if _G.InfinityPathFinding and _G.InfinityPathFinding.SetWaypoint and x and y then
		pcall(function() _G.InfinityPathFinding:SetWaypoint(x, y, mapID or 0, title or "Guild Waypoint") end)
	end
end

function InfinityHiveDistress:CheckTargetRare()
	local cfg = InfinityHive:GetConfig()
	if not cfg.shareWorldEvents or not IsInOpenWorld() then return end
	if not UnitExists or not UnitExists("target") then return end
	if UnitIsDead and UnitIsDead("target") then return end

	local classification = UnitClassification and UnitClassification("target")
	if classification ~= "rare" and classification ~= "rareelite" and classification ~= "worldboss" then
		return
	end

	local name = UnitName("target")
	local level = UnitLevel("target")
	if not name or InfinityUtils:IsSecret(name) or InfinityUtils:IsSecret(level) then return end

	local now = GetTime()
	if self.lastRareSeen[name] and (now - self.lastRareSeen[name]) < 600 then
		return
	end
	self.lastRareSeen[name] = now

	local px, py, mapID = InfinityUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local payload = string.format("%s|%d|%s|%d|%s|%.3f|%.3f",
		name:gsub("|", " "), level or 0, classification, mapID or 0, zone:gsub("|", " "), px or 0, py or 0)
	InfinityHive:Send("RARE", payload, "GUILD")
	InfinityHive:AddFeedEvent("RARE", string.format("Spotted %s (%s) in %s (%.1f, %.1f)", name, classification, zone, (px or 0) * 100, (py or 0) * 100))
end

function InfinityHiveDistress:BroadcastActiveZoneQuests()
	local cfg = InfinityHive:GetConfig()
	if not cfg.shareWorldEvents then return end
	local now = GetTime()
	if (now - self.lastQuestBroadcast) < 45 then return end
	self.lastQuestBroadcast = now

	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local qids = {}
	local count = InfinityUtils and InfinityUtils:GetQuestLogCount() or 0
	for i = 1, count do
		local _, _, isHeader, questID = InfinityUtils:GetQuestLogEntry(i)
		if not isHeader and questID and type(questID) == "number" and questID > 0 then
			table.insert(qids, tostring(questID))
			if #qids >= 25 then break end
		end
	end
	if #qids > 0 then
		InfinityHive:Send("QZONE", zone:gsub("|", " ") .. "|" .. table.concat(qids, ","), "GUILD")
	end
end

function InfinityHiveDistress:GetGuildmatesOnSameQuest()
	local db = InfinityHive:GetDB()
	local me = InfinityHive:GetPlayerShortName()
	local myQuests = {}
	local count = InfinityUtils and InfinityUtils:GetQuestLogCount() or 0
	for i = 1, count do
		local title, _, isHeader, qid = InfinityUtils:GetQuestLogEntry(i)
		if not isHeader and qid then
			myQuests[qid] = title or ("Quest #" .. qid)
		end
	end

	local overlaps = {}
	local now = time()
	for memberName, entry in pairs(db.questZones or {}) do
		if memberName ~= me and (now - (entry.updatedAt or 0)) <= 1800 then
			for qid in pairs(entry.quests or {}) do
				if myQuests[qid] then
					table.insert(overlaps, {
						member = memberName,
						questID = qid,
						questTitle = myQuests[qid],
						zone = entry.zone or "Azeroth",
					})
				end
			end
		end
	end
	return overlaps
end

function InfinityHiveDistress:Initialize()
	if self.initialized then return end
	self.initialized = true

	InfinityHive:RegisterHandler("SOS", function(sender, body)
		InfinityHiveDistress:HandleIncomingSOS(sender, body)
	end)

	InfinityHive:RegisterHandler("RARE", function(sender, body)
		local name, lvl, cls, mapID, zone, x, y = body:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if not name or name == "" then return end
		local db = InfinityHive:GetDB()
		db.rares[name] = {
			name = name,
			level = tonumber(lvl) or 0,
			classification = cls or "rare",
			mapID = tonumber(mapID) or 0,
			zone = zone or "Azeroth",
			x = tonumber(x) or 0,
			y = tonumber(y) or 0,
			spottedBy = sender,
			seenAt = time(),
		}
		InfinityHive:AddFeedEvent("RARE", string.format("%s spotted %s in %s (%.1f, %.1f)", sender, name, zone or "?", (tonumber(x) or 0) * 100, (tonumber(y) or 0) * 100))
	end)

	InfinityHive:RegisterHandler("NODE", function(sender, body)
		local nodeType, zone, xStr, yStr = body:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
		local x, y = tonumber(xStr) or 0, tonumber(yStr) or 0
		if x > 0 or y > 0 then
			if _G.InfinityNodeDB and _G.InfinityNodeDB.RecordNode then
				pcall(function() _G.InfinityNodeDB:RecordNode(nodeType or "herb", x * 100, y * 100, zone or "Azeroth", 300) end)
			end
			if _G.InfinityDataCollectorCore and _G.InfinityDataCollectorCore.RecordNodeData then
				local nid = math.floor(x * 1000) * 1000 + math.floor(y * 1000)
				pcall(function() _G.InfinityDataCollectorCore:RecordNodeData(nodeType or "herb", nid, x * 100, y * 100, zone or "Azeroth", 0, 300) end)
			end
		end
	end)

	InfinityHive:RegisterHandler("QZONE", function(sender, body)
		local zone, qStr = body:match("^([^|]*)|(.*)$")
		local quests = {}
		for qidStr in (qStr or ""):gmatch("(%d+)") do
			local qid = tonumber(qidStr)
			if qid then quests[qid] = true end
		end
		local db = InfinityHive:GetDB()
		db.questZones[sender] = { zone = zone or "Azeroth", quests = quests, updatedAt = time() }
	end)

	local GATHER_SPELLS = { [2366] = "herb", [2575] = "mining", [8613] = "skinning", [7620] = "fishing" }

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "UNIT_HEALTH", "PLAYER_TARGET_CHANGED", "UNIT_SPELLCAST_SUCCEEDED", "QUEST_LOG_UPDATE", "ZONE_CHANGED_NEW_AREA" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	f:SetScript("OnEvent", function(_, event, arg1, _, arg3)
		if event == "UNIT_HEALTH" and arg1 == "player" then
			if InCombatLockdown and InCombatLockdown() and IsInOpenWorld() then
				local hp = UnitHealth("player")
				local hpMax = UnitHealthMax("player")
				if not InfinityUtils:IsSecret(hp) and not InfinityUtils:IsSecret(hpMax) and hpMax > 0 then
					local pct = (hp / hpMax) * 100
					local threshold = InfinityHive:GetConfig().distressHpThreshold or 35
					if pct > 0 and pct <= threshold then
						InfinityHiveDistress:BroadcastSOS(false)
					end
				end
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			InfinityHiveDistress:CheckTargetRare()
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" and arg3 and not InfinityUtils:IsSecret(arg3) then
			local nodeType = GATHER_SPELLS[arg3]
			if nodeType and InfinityHive:GetConfig().shareWorldEvents and IsInOpenWorld() then
				local px, py = InfinityUtils:GetUnitMapPosition("player")
				local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
				if px and py and (px > 0 or py > 0) then
					InfinityHive:Send("NODE", string.format("%s|%s|%.4f|%.4f", nodeType, zone:gsub("|", " "), px, py), "GUILD")
				end
			end
		elseif event == "QUEST_LOG_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
			InfinityHiveDistress:BroadcastActiveZoneQuests()
		end
	end)
end

return InfinityHiveDistress
