-- PluribusHive Open-World Distress (SOS), Rescue Popup, Rare Sharing & Quest Overlap
-- Strictly OPEN-WORLD ONLY: automatically disabled inside dungeons, raids, arenas, and battlegrounds
-- Incoming nearby SOS alerts display a dedicated SOS Rescue Popup with 1-Click [Invite + Navigate]

PluribusHiveDistress = {
	initialized = false,
	lastSOSSentAt = 0,
	activeAlerts = {},
	myQuests = {},
	seenRares = {},
	sosPopup = nil,
}
_G.PluribusHiveDistress = PluribusHiveDistress

local SOS_COOLDOWN = 45
local RARE_COOLDOWN = 120

function PluribusHiveDistress:IsOpenWorld()
	if IsInInstance then
		local inInstance, instanceType = IsInInstance()
		if inInstance or (instanceType and instanceType ~= "none") then
			return false
		end
	end
	return true
end

function PluribusHiveDistress:GetPlayerPosition()
	local mapID = 0
	if C_Map and C_Map.GetBestMapForUnit then
		mapID = C_Map.GetBestMapForUnit("player") or 0
	end
	local x, y = 0, 0
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local px, py = _G.PluribusUtils:GetUnitMapPosition("player")
		x, y = px or 0, py or 0
	end
	local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "Azeroth"
	return mapID, x, y, zone
end

function PluribusHiveDistress:BroadcastSOS(isManual)
	if not self:IsOpenWorld() then return false end
	local cfg = PluribusHive:GetConfig()
	if not cfg.shareDistress then return false end

	local now = time()
	if not isManual and (now - self.lastSOSSentAt) < SOS_COOLDOWN then return false end
	self.lastSOSSentAt = now

	local mapID, x, y, zone = self:GetPlayerPosition()
	local hp = UnitHealth and UnitHealth("player") or 1
	local maxHp = math.max(1, UnitHealthMax and UnitHealthMax("player") or 100)
	local hpPct = math.floor((hp / maxHp) * 100)
	local attacker = (UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target") and UnitName("target")) or "Hostile"
	if PluribusUtils and PluribusUtils.IsSecret and PluribusUtils:IsSecret(attacker) then
		attacker = "Hostile"
	end
	local cls = PluribusHive:GetPlayerClass()
	local lvl = (UnitLevel and UnitLevel("player")) or 60

	local payload = string.format("%d|%.4f|%.4f|%d|%s|%s|%s|%d",
		mapID, x, y, hpPct,
		tostring(zone):gsub("|", " "),
		tostring(attacker):gsub("|", " "),
		cls, lvl
	)

	PluribusHive:Send("SOS", payload, "GUILD", nil, true)
	PluribusHive:AddFeedEvent("SOS", string.format("You sent open-world SOS in %s (%d%% HP)", zone, hpPct))
	if isManual and _G.PluribusUIFramework then
		local L = _G.PluribusL
		_G.PluribusUIFramework:ShowNotification("|cfff87171" .. (L and L:Get("SOS_SENT") or "Open-world SOS sent to nearby guildmates!") .. "|r", 3)
	end
	return true
end

-- Helper: Invite player cross-API (Classic 1.60.1 InviteUnit + modern C_PartyInfo.InviteUnit)
function PluribusHiveDistress:InvitePlayer(playerName)
	if not playerName or playerName == "" then return false end
	if C_PartyInfo and C_PartyInfo.InviteUnit then
		pcall(C_PartyInfo.InviteUnit, playerName)
		return true
	elseif InviteUnit then
		pcall(InviteUnit, playerName)
		return true
	end
	return false
end

-- Dedicated crisp SOS Rescue Popup with 1-Click [Invite + Navigate] & [Navigate Only]
function PluribusHiveDistress:ShowRescuePopup(alert)
	local UI = _G.PluribusUIFramework
	if not UI or not alert then return end
	local L = _G.PluribusL

	if not self.sosPopup then
		local f = CreateFrame("Frame", "PluribusSOSRescuePopup", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f:SetSize(354, 128)
		f:SetPoint("TOP", UIParent, "TOP", 0, -170)
		f:SetFrameStrata("DIALOG")
		f:SetMovable(true)
		f:EnableMouse(true)
		f:SetClampedToScreen(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		UI:ApplyBackdrop(f, 0.08, 0.04, 0.06, 0.97, 0.95, 0.28, 0.30, 1.0)

		local header = UI:CreateLabel(f, "", 1.0, 0.36, 0.38, "GameFontNormal")
		header:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -10)
		f.header = header

		local closeBtn = UI:CreateButton(f, "X", 22, 18, function()
			f:Hide()
		end)
		closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)

		local iconSlot = UI:CreateClassIcon(f, "WARRIOR", 34)
		iconSlot:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
		f.classIcon = iconSlot

		local infoLbl = UI:CreateLabel(f, "", 0.96, 0.96, 1.0, "GameFontNormal")
		infoLbl:SetPoint("TOPLEFT", iconSlot, "TOPRIGHT", 10, 0)
		infoLbl:SetWidth(286)
		f.infoLbl = infoLbl

		local subLbl = UI:CreateLabel(f, "", 0.85, 0.78, 0.82, "GameFontHighlightSmall")
		subLbl:SetPoint("TOPLEFT", infoLbl, "BOTTOMLEFT", 0, -3)
		subLbl:SetWidth(286)
		f.subLbl = subLbl

		local invNavBtn = UI:CreateButton(f, L and L:Get("SOS_INVITE_NAV") or "Invite + Navigate", 168, 26, function()
			local a = f._alert
			if not a then return end
			PluribusHiveDistress:InvitePlayer(a.sender)
			if _G.PluribusNavigationUI and _G.PluribusNavigationUI.SetWaypoint then
				_G.PluribusNavigationUI:SetWaypoint("SOS: " .. a.sender, a.zone, a.x * 100, a.y * 100, a.mapID)
			end
			if SendChatMessage then
				local msg = (L and L:Get("SOS_WHISPER_OMW")) or "On my way to rescue you! Group invite sent!"
				pcall(SendChatMessage, msg, "WHISPER", nil, a.sender)
			end
			f:Hide()
		end, true)
		invNavBtn:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 12, 10)
		f.invNavBtn = invNavBtn

		local navBtn = UI:CreateButton(f, L and L:Get("SOS_NAV_ONLY") or "Navigate Only", 148, 26, function()
			local a = f._alert
			if not a then return end
			if _G.PluribusNavigationUI and _G.PluribusNavigationUI.SetWaypoint then
				_G.PluribusNavigationUI:SetWaypoint("SOS: " .. a.sender, a.zone, a.x * 100, a.y * 100, a.mapID)
			end
			if SendChatMessage then
				local msg = (L and L:Get("SOS_WHISPER_NAV")) or "On my way to help! Hold on!"
				pcall(SendChatMessage, msg, "WHISPER", nil, a.sender)
			end
			f:Hide()
		end)
		navBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
		f.navBtn = navBtn

		f:Hide()
		self.sosPopup = f
	end

	local f = self.sosPopup
	f._alert = alert
	f.header:SetText("|cfff87171" .. (L and L:Get("SOS_POPUP_TITLE") or "GUILD SOS — RESCUE NEEDED!") .. "|r")
	if f.invNavBtn and f.invNavBtn.label then
		f.invNavBtn.label:SetText(L and L:Get("SOS_INVITE_NAV") or "Invite + Navigate")
	end
	if f.navBtn and f.navBtn.label then
		f.navBtn.label:SetText(L and L:Get("SOS_NAV_ONLY") or "Navigate Only")
	end

	local _, _, _, hex = UI:GetClassColor(alert.class or "WARRIOR")
	f.infoLbl:SetText(string.format("%s%s|r (Lv%d) — |cfff87171%d%% HP|r", hex, alert.sender, alert.level or 60, alert.hpPct or 25))
	local distTxt = alert.yards and string.format(" (~%d yds)", alert.yards) or ""
	f.subLbl:SetText(string.format("%s (%.1f, %.1f)%s · vs |cfffbbf24%s|r", alert.zone, alert.x * 100, alert.y * 100, distTxt, alert.attacker or "Hostile"))

	local expireAt = GetTime() + 30
	f:SetScript("OnUpdate", function(selfF)
		if GetTime() >= expireAt then
			selfF:SetScript("OnUpdate", nil)
			selfF:Hide()
		end
	end)
	f:Show()
	if PlaySound and SOUNDKIT and SOUNDKIT.RAID_WARNING then
		pcall(PlaySound, SOUNDKIT.RAID_WARNING)
	end
end

function PluribusHiveDistress:OnReceiveSOS(sender, body)
	if PluribusHive:SamePlayer(sender, PluribusHive:GetPlayerShortName()) then return end
	if not self:IsOpenWorld() then return end

	local cfg = PluribusHive:GetConfig()
	if not cfg.showDistressAlerts then return end

	local mapStr, xStr, yStr, hpStr, zone, attacker, cls, lvlStr =
		tostring(body or ""):match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|?([^|]*)|?(.*)$")
	local rMap = tonumber(mapStr) or 0
	local rx = tonumber(xStr) or 0
	local ry = tonumber(yStr) or 0
	local hpPct = tonumber(hpStr) or 25
	zone = (zone and zone ~= "") and zone or "Azeroth"
	attacker = (attacker and attacker ~= "") and attacker or "Hostile"
	cls = (cls and cls ~= "") and cls or "WARRIOR"
	local lvl = tonumber(lvlStr) or 60

	local myMap, mx, my, myZone = self:GetPlayerPosition()
	local sameZone = (rMap > 0 and myMap > 0 and rMap == myMap)
		or (zone:lower() == myZone:lower())
	if not sameZone then return end

	local dx, dy = (rx - mx), (ry - my)
	local dist = math.sqrt(dx * dx + dy * dy)
	local maxDist = tonumber(cfg.distressMaxDistance) or 0.18
	if (mx > 0 or my > 0) and (rx > 0 or ry > 0) and dist > maxDist then
		return
	end

	local yards = (mx > 0 or my > 0) and math.floor(dist * 2800) or nil
	local alert = {
		sender = PluribusHive:NormalizeName(sender),
		mapID = rMap,
		x = rx,
		y = ry,
		hpPct = hpPct,
		zone = zone,
		attacker = attacker,
		class = cls,
		level = lvl,
		yards = yards,
		time = time(),
	}
	table.insert(self.activeAlerts, 1, alert)
	while #self.activeAlerts > 10 do table.remove(self.activeAlerts) end

	PluribusHive:AddFeedEvent("SOS", string.format("%s needs help in %s (%d%% HP vs %s)", alert.sender, zone, hpPct, attacker))
	self:ShowRescuePopup(alert)
end

-- Share rare mob sighting in open world
function PluribusHiveDistress:CheckTargetForRare()
	if not self:IsOpenWorld() then return end
	if not PluribusHive:GetConfig().shareWorldEvents then return end
	if not UnitExists or not UnitExists("target") or UnitIsDead("target") or UnitIsPlayer("target") then return end

	local cls = UnitClassification and UnitClassification("target") or ""
	if cls ~= "rare" and cls ~= "rareelite" then return end

	local name = UnitName("target")
	if not name or (PluribusUtils and PluribusUtils.IsSecret and PluribusUtils:IsSecret(name)) then return end
	local now = time()
	if self.seenRares[name] and (now - self.seenRares[name]) < RARE_COOLDOWN then return end
	self.seenRares[name] = now

	local mapID, x, y, zone = self:GetPlayerPosition()
	local lvl = UnitLevel and UnitLevel("target") or 0
	local payload = string.format("%s|%d|%d|%.4f|%.4f|%s", name:gsub("|", " "), lvl, mapID, x, y, zone:gsub("|", " "))
	PluribusHive:Send("RARE", payload, "GUILD")
	PluribusHive:AddFeedEvent("RARE", string.format("You spotted rare %s (Lv%d) in %s", name, lvl, zone))
end

-- Quest overlap sharing (tells guildmates silently when you're on the same quests)
function PluribusHiveDistress:ScanAndBroadcastQuests()
	if not PluribusHive:GetConfig().shareWorldEvents then return end
	local titles = {}
	if C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo then
		for i = 1, C_QuestLog.GetNumQuestLogEntries() do
			local info = C_QuestLog.GetInfo(i)
			if info and not info.isHeader and info.title and not info.isHidden then
				local cleanTitle = (info.title:gsub("[|,]", " "))
				table.insert(titles, cleanTitle)
				if #titles >= 15 then break end
			end
		end
	elseif GetNumQuestLogEntries and GetQuestLogTitle then
		for i = 1, GetNumQuestLogEntries() do
			local title, _, _, isHeader = GetQuestLogTitle(i)
			if title and not isHeader then
				local cleanTitle = (title:gsub("[|,]", " "))
				table.insert(titles, cleanTitle)
				if #titles >= 15 then break end
			end
		end
	end

	self.myQuests = {}
	for _, t in ipairs(titles) do self.myQuests[t:lower()] = t end

	local _, _, _, zone = self:GetPlayerPosition()
	local db = PluribusHive:GetDB()
	local me = PluribusHive:GetPlayerShortName()
	db.questZones[me] = { zone = zone, quests = titles, updatedAt = time() }

	if #titles > 0 then
		PluribusHive:Send("QUEST", zone:gsub("|", " ") .. "|" .. table.concat(titles, ","), "GUILD")
	end
end

function PluribusHiveDistress:GetGuildmatesOnSameQuest()
	local db = PluribusHive:GetDB()
	local me = PluribusHive:GetPlayerShortName()
	local matches = {}
	for member, rec in pairs(db.questZones or {}) do
		if not PluribusHive:SamePlayer(member, me) and rec.quests then
			for _, q in ipairs(rec.quests) do
				if self.myQuests[q:lower()] then
					table.insert(matches, { member = member, questTitle = q, zone = rec.zone or "Azeroth" })
				end
			end
		end
	end
	return matches
end

function PluribusHiveDistress:Initialize()
	if self.initialized then return end
	self.initialized = true

	PluribusHive:RegisterHandler("SOS", function(sender, body)
		PluribusHiveDistress:OnReceiveSOS(sender, body)
	end)

	PluribusHive:RegisterHandler("RARE", function(sender, body)
		if PluribusHive:SamePlayer(sender, PluribusHive:GetPlayerShortName()) then return end
		local rName, lvlStr, mapStr, xStr, yStr, zone =
			tostring(body or ""):match("^([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if not rName or rName == "" then return end
		local db = PluribusHive:GetDB()
		db.rares[rName] = { name = rName, level = tonumber(lvlStr) or 0, mapID = tonumber(mapStr) or 0, x = tonumber(xStr) or 0, y = tonumber(yStr) or 0, zone = zone or "", reporter = sender, seenAt = time() }
		PluribusHive:AddFeedEvent("RARE", string.format("%s spotted rare %s in %s", sender, rName, zone or ""))

		if PluribusHiveDistress:IsOpenWorld() and _G.PluribusHiveUI then
			local _, _, _, myZone = PluribusHiveDistress:GetPlayerPosition()
			if myZone:lower() == tostring(zone or ""):lower() then
				_G.PluribusHiveUI:ShowToast({
					title = "Rare Spotted Nearby: " .. rName,
					body = string.format("%s spotted Lv%d %s in %s (%.1f, %.1f)", sender, tonumber(lvlStr) or 0, rName, zone or "", (tonumber(xStr) or 0) * 100, (tonumber(yStr) or 0) * 100),
					color = { 0.96, 0.72, 0.16 },
					duration = 10,
					action1 = {
						label = "Set Waypoint",
						onClick = function()
							if _G.PluribusNavigationUI and _G.PluribusNavigationUI.SetWaypoint then
								_G.PluribusNavigationUI:SetWaypoint("Rare: " .. rName, zone or "", (tonumber(xStr) or 0) * 100, (tonumber(yStr) or 0) * 100, tonumber(mapStr) or 0)
							end
						end,
					},
				})
			end
		end
	end)

	PluribusHive:RegisterHandler("QUEST", function(sender, body)
		if PluribusHive:SamePlayer(sender, PluribusHive:GetPlayerShortName()) then return end
		local zone, qList = tostring(body or ""):match("^([^|]*)|(.*)$")
		local quests = {}
		for q in tostring(qList or ""):gmatch("[^,]+") do
			table.insert(quests, q)
		end
		local db = PluribusHive:GetDB()
		db.questZones[PluribusHive:NormalizeName(sender)] = { zone = zone or "", quests = quests, updatedAt = time() }
	end)

	local f = CreateFrame("Frame")
	for _, ev in ipairs({ "UNIT_HEALTH", "PLAYER_TARGET_CHANGED", "QUEST_LOG_UPDATE", "PLAYER_ENTERING_WORLD" }) do
		pcall(f.RegisterEvent, f, ev)
	end

	local questThrottle = 0
	f:SetScript("OnEvent", function(_, event, unit)
		if event == "UNIT_HEALTH" and unit == "player" then
			if not PluribusHiveDistress:IsOpenWorld() then return end
			if not (UnitAffectingCombat and UnitAffectingCombat("player")) then return end
			local hp = UnitHealth and UnitHealth("player") or 1
			local maxHp = math.max(1, UnitHealthMax and UnitHealthMax("player") or 1)
			local pct = (hp / maxHp) * 100
			local thresh = tonumber(PluribusHive:GetConfig().distressHpThreshold) or 35
			if hp > 0 and pct <= thresh then
				PluribusHiveDistress:BroadcastSOS(false)
			end
		elseif event == "PLAYER_TARGET_CHANGED" then
			PluribusHiveDistress:CheckTargetForRare()
		elseif event == "QUEST_LOG_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
			local now = GetTime()
			if (now - questThrottle) > 30 then
				questThrottle = now
				if C_Timer and C_Timer.After then
					C_Timer.After(4, function() PluribusHiveDistress:ScanAndBroadcastQuests() end)
				end
			end
		end
	end)
end

return PluribusHiveDistress
