-- PluribusHive Open-World Distress, Rare Spotting, Shared Nodes & Quest Overlap
-- Strictly NEVER triggers distress warnings inside instances, raids, BGs, or arenas
-- Warns nearby guildmates only when close enough to arrive and help in time

PluribusHiveDistress = {
	initialized = false,
	lastSOSSent = 0,
	lastSOSBySender = {},
	lastRareSeen = {},
	lastQuestBroadcast = 0,
}
_G.PluribusHiveDistress = PluribusHiveDistress

local function IsInOpenWorld()
	if IsInInstance then
		local inInstance, instanceType = IsInInstance()
		if inInstance or (instanceType and instanceType ~= "none") then
			return false
		end
	end
	return true
end

function PluribusHiveDistress:BroadcastSOS(manual)
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareDistress then return false end
	if not IsInOpenWorld() then return false end

	local now = GetTime()
	if not manual and (now - self.lastSOSSent) < 35 then
		return false
	end

	local hp = UnitHealth and UnitHealth("player") or 0
	local hpMax = UnitHealthMax and UnitHealthMax("player") or 1
	if PluribusUtils:IsSecret(hp) or PluribusUtils:IsSecret(hpMax) or hpMax <= 0 then
		return false
	end
	local hpPct = math.floor((hp / hpMax) * 100)
	local px, py, mapID = PluribusUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local subzone = (GetSubZoneText and GetSubZoneText()) or ""
	local attacker = "Danger"
	if UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") then
		local tName = UnitName("target")
		if tName and not PluribusUtils:IsSecret(tName) then
			attacker = tName
		end
	end

	self.lastSOSSent = now
	local payload = string.format("%s|%d|%s|%s|%.4f|%.4f|%d|%s",
		PluribusHive:GetPlayerClass(),
		mapID or 0,
		zone:gsub("|", " "),
		subzone:gsub("|", " "),
		px or 0,
		py or 0,
		hpPct,
		attacker:gsub("|", " ")
	)
	PluribusHive:Send("SOS", payload, "GUILD", nil, true)
	PluribusHive:AddFeedEvent("SOS", "Sent distress ping in " .. zone .. string.format(" (%.1f, %.1f)", (px or 0) * 100, (py or 0) * 100))
	return true
end

function PluribusHiveDistress:HandleIncomingSOS(sender, body)
	local cfg = PluribusHive:GetConfig()
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
	local mx, my, myMapID = PluribusUtils:GetUnitMapPosition("player")
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

	PluribusHive:AddFeedEvent("SOS", string.format("%s needs help (%d%% HP vs %s) — ~%ds away at %s", sender, hpPct, attacker or "Mob", etaSec, locText))

	if _G.PluribusHiveUI and _G.PluribusHiveUI.ShowToast then
		_G.PluribusHiveUI:ShowToast({
			kind = "SOS",
			title = string.format("Guildmate in Danger: %s (%d%% HP)", sender, hpPct),
			body = string.format("Fighting %s · %s · ~%ds away", attacker or "Enemy", locText, etaSec),
			color = { 0.94, 0.27, 0.27 },
			duration = 14,
			action1 = {
				label = "Set Waypoint",
				onClick = function()
					PluribusHiveDistress:SetRescueWaypoint(mapID, tx, ty, sender .. " (SOS)")
				end,
			},
			action2 = {
				label = "On my way!",
				onClick = function()
					if SendChatMessage then
						pcall(SendChatMessage, "On my way to help! Hold on!", "WHISPER", nil, sender)
					end
					PluribusHiveDistress:SetRescueWaypoint(mapID, tx, ty, sender .. " (SOS)")
				end,
			},
		})
	end
end

function PluribusHiveDistress:SetRescueWaypoint(mapID, x, y, title)
	if mapID and mapID > 0 and x and y and C_Map and C_Map.SetUserWaypoint and UiMapPoint and UiMapPoint.CreateFromCoordinates then
		pcall(function()
			C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(mapID, x, y))
			if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then
				C_SuperTrack.SetSuperTrackedUserWaypoint(true)
			end
		end)
	end
	if _G.PluribusPathFinding and _G.PluribusPathFinding.SetWaypoint and x and y then
		pcall(function() _G.PluribusPathFinding:SetWaypoint(x, y, mapID or 0, title or "Guild Waypoint") end)
	end
end

function PluribusHiveDistress:CheckTargetRare()
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareWorldEvents or not IsInOpenWorld() then return end
	if not UnitExists or not UnitExists("target") then return end
	if UnitIsDead and UnitIsDead("target") then return end

	local classification = UnitClassification and UnitClassification("target")
	if classification ~= "rare" and classification ~= "rareelite" and classification ~= "worldboss" then
		return
	end

	local name = UnitName("target")
	local level = UnitLevel("target")
	if not name or PluribusUtils:IsSecret(name) or PluribusUtils:IsSecret(level) then return end

	local now = GetTime()
	if self.lastRareSeen[name] and (now - self.lastRareSeen[name]) < 600 then
		return
	end
	self.lastRareSeen[name] = now

	local px, py, mapID = PluribusUtils:GetUnitMapPosition("player")
	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local payload = string.format("%s|%d|%s|%d|%s|%.3f|%.3f",
		name:gsub("|", " "), level or 0, classification, mapID or 0, zone:gsub("|", " "), px or 0, py or 0)
	PluribusHive:Send("RARE", payload, "GUILD")
	PluribusHive:AddFeedEvent("RARE", string.format("Spotted %s (%s) in %s (%.1f, %.1f)", name, classification, zone, (px or 0) * 100, (py or 0) * 100))
end

function PluribusHiveDistress:BroadcastActiveZoneQuests()
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareWorldEvents then return end
	local now = GetTime()
	if (now - self.lastQuestBroadcast) < 45 then return end
	self.lastQuestBroadcast = now

	local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local qids = {}
	local count = PluribusUtils and PluribusUtils:GetQuestLogCount() or 0
	for i = 1, count do
		local _, _, isHeader, questID = PluribusUtils:GetQuestLogEntry(i)
		if not isHeader and questID and type(questID) == "number" and questID > 0 then
			table.insert(qids, tostring(questID))
			if #qids >= 25 then break end
		end
	end
	if #qids > 0 then
		PluribusHive:Send("QZONE", zone:gsub("|", " ") .. "|" .. table.concat(qids, ","), "GUILD")
	end
end

function PluribusHiveDistress:GetGuildmatesOnSameQuest()
	local db = PluribusHive:GetDB()
	local me = PluribusHive:GetPlayerShortName()
	local myQuests = {}
	local count = PluribusUtils and PluribusUtils:GetQuestLogCount() or 0
	for i = 1, count do
		local title, _, isHeader, qid = PluribusUtils:GetQuestLogEntry(i)
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

function PluribusHiveDistress:Initialize()
	if self.initialized then return end
	self.initialized = true

	PluribusHive:RegisterHandler("SOS", function(sender, body)
		PluribusHiveDistress:HandleIncomingSOS(sender, body)
	end)

	PluribusHive:RegisterHandler("RARE", function(sender, body)
		local name, lvl, cls, mapID, zone, x, y = body:match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if not name or name == "" then return end
		local db = PluribusHive:GetDB()
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
		PluribusHive:AddFeedEvent("RARE", string.format("%s spotted %s in %s (%.1f, %.1f)", sender, name, zone or "?", (tonumber(x) or 0) * 100, (tonumber(y) or 0) * 100))
	end)

	PluribusHive:RegisterHandler("NODE", function(sender, body)
		local nodeType, zone, xStr, yStr = body:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
		local x, y = tonumber(xStr) or 0, tonumber(yStr) or 0
		if x > 0 or y > 0 then
			if _G.PluribusNodeDB and _G.PluribusNodeDB.RecordNode then
				pcall(function() _G.PluribusNodeDB:RecordNode(nodeType or "herb", x * 100, y * 100, zone or "Azeroth", 300) end)
			end
			if _G.PluribusDataCollectorCore and _G.PluribusDataCollectorCore.RecordNodeData then
				local nid = math.floor(x * 1000) * 1000 + math.floor(y * 1000)
				pcall(function() _G.PluribusDataCollectorCore:RecordNodeData(nodeType or "herb", nid, x * 100, y * 100, zone or "Azeroth", 0, 300) end)
			end
		end
	end)

	PluribusHive:RegisterHandler("QZONE", function(sender, body)
		local zone, qStr = body:match("^([^|]*)|(.*)$")
		local quests = {}
		for qidStr in (qStr or ""):gmatch("(%d+)") do
			local qid = tonumber(qidStr)
			if qid then quests[qid] = true end
		end
		local db = PluribusHive:GetDB()
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
				if not PluribusUtils:IsSecret(hp) and not PluribusUtils:IsSecret(hpMax) and hpMax > 0 then
					local pct = (hp / hpMax) * 100
					local threshold = PluribusHive:GetConfig().distressHpThreshold or 35
					if pct > 0 and pct <= threshold then
						PluribusHiveDistress:BroadcastSOS(false)
					end
				end
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			PluribusHiveDistress:CheckTargetRare()
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" and arg1 == "player" and arg3 and not PluribusUtils:IsSecret(arg3) then
			local nodeType = GATHER_SPELLS[arg3]
			if nodeType and PluribusHive:GetConfig().shareWorldEvents and IsInOpenWorld() then
				local px, py = PluribusUtils:GetUnitMapPosition("player")
				local zone = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
				if px and py and (px > 0 or py > 0) then
					PluribusHive:Send("NODE", string.format("%s|%s|%.4f|%.4f", nodeType, zone:gsub("|", " "), px, py), "GUILD")
				end
			end
		elseif event == "QUEST_LOG_UPDATE" or event == "ZONE_CHANGED_NEW_AREA" then
			PluribusHiveDistress:BroadcastActiveZoneQuests()
		end
	end)
end

return PluribusHiveDistress
