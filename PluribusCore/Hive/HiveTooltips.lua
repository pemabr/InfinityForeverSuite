-- PluribusHive Item & Unit (Mob/NPC Quest) Tooltips Integration
-- Multi-API hooks for Warcraft Forever 1.60.1 (TooltipDataProcessor + OnTooltipSetItem/Unit + direct Set* hooks)
-- Displays on Items: You/Alts/Guild Bag+Bank counts, Guild Profession Needs, AH Market Price, Hive DB & GearAdvisor
-- Displays on Mobs/NPCs: Available Quests they give (!), Ready Turn-Ins (?), and Active Quest Objectives (• 3/10)

PluribusHiveTooltips = {
	initialized = false,
	_recentMobTargets = {},
	_lastObjSnapshot = {},
}
_G.PluribusHiveTooltips = PluribusHiveTooltips

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

local function FormatAge(ts)
	if not ts or ts <= 0 then return "" end
	local diff = math.max(0, time() - ts)
	if diff < 60 then return "now"
	elseif diff < 3600 then return math.floor(diff / 60) .. "m ago"
	elseif diff < 86400 then return math.floor(diff / 3600) .. "h ago"
	else return math.floor(diff / 86400) .. "d ago" end
end

local function HasAnyScannedAHPrices()
	if not _G.PluribusHive then return false end
	local db = _G.PluribusHive:GetDB()
	return db and db.prices and next(db.prices) ~= nil or false
end

local function TooltipAlreadyHasPluribus(tooltip)
	if not tooltip or not tooltip.GetName or not tooltip.NumLines then return false end
	local name = tooltip:GetName()
	if not name then return false end
	local num = tooltip:NumLines() or 0
	for i = math.max(1, num - 12), num do
		local leftFS = _G[name .. "TextLeft" .. i]
		local txt = leftFS and leftFS.GetText and leftFS:GetText()
		if type(txt) == "string" and (txt:find("AH Price:", 1, true) or txt:find("Hive Bags:", 1, true) or txt:find("GearAdvisor:", 1, true)) then
			return true
		end
	end
	return false
end

local function TooltipAlreadyHasUnitQuests(tooltip)
	if not tooltip or not tooltip.GetName or not tooltip.NumLines then return false end
	local name = tooltip:GetName()
	if not name then return false end
	local num = tooltip:NumLines() or 0
	for i = math.max(1, num - 12), num do
		local leftFS = _G[name .. "TextLeft" .. i]
		local txt = leftFS and leftFS.GetText and leftFS:GetText()
		if type(txt) == "string" and (
			txt:find("Questgeber:", 1, true)
			or txt:find("Quest Giver:", 1, true)
			or txt:find("Quest-Abgabe:", 1, true)
			or txt:find("Quest Turn-In:", 1, true)
			or txt:find("Quest-Ziel:", 1, true)
			or txt:find("Quest Target:", 1, true)
		) then
			return true
		end
	end
	return false
end

local function IsAllowedPlayerTooltip(tooltip)
	if not tooltip then return false end
	if tooltip._plbIsScanner then return false end
	if tooltip == _G.GameTooltip or tooltip == _G.ItemRefTooltip
		or tooltip == _G.ShoppingTooltip1 or tooltip == _G.ShoppingTooltip2 then
		return true
	end
	return false
end

-- ============================================================================
-- PASSIVE QUEST-NPC KNOWLEDGE INDEX (Local + Guild P2P + Optional QuestieDB)
-- ============================================================================
local function EnsureQuestNpcIndex()
	if _G.PluribusHive and _G.PluribusHive.GetDB then
		local db = _G.PluribusHive:GetDB()
		db.questNpcIndex = db.questNpcIndex or { npcs = {}, quests = {} }
		db.questNpcIndex.npcs = db.questNpcIndex.npcs or {}
		db.questNpcIndex.quests = db.questNpcIndex.quests or {}
		return db.questNpcIndex
	end
	PluribusHiveTooltips._fallbackIndex = PluribusHiveTooltips._fallbackIndex or { npcs = {}, quests = {} }
	return PluribusHiveTooltips._fallbackIndex
end

local function ExtractNpcIdFromGUID(guid)
	if type(guid) ~= "string" then return nil end
	if _G.PluribusUtils and _G.PluribusUtils.IsSecret and _G.PluribusUtils:IsSecret(guid) then return nil end
	local unitType, _, _, _, _, npcId = guid:match("^(%a+)%-(%d+)%-(%d+)%-(%d+)%-(%d+)%-(%d+)")
	if (unitType == "Creature" or unitType == "Vehicle") and npcId then
		return tonumber(npcId)
	end
	return nil
end

local function GetCurrentZoneCoords()
	local z = (GetRealZoneText and GetRealZoneText()) or "Azeroth"
	local x, y = 50, 50
	if _G.PluribusUtils and _G.PluribusUtils.GetUnitMapPosition then
		local ux, uy = _G.PluribusUtils:GetUnitMapPosition("player")
		if ux and uy and (ux > 0 or uy > 0) then
			x = math.floor(ux * 1000 + 0.5) / 10
			y = math.floor(uy * 1000 + 0.5) / 10
		end
	end
	return z, x, y
end

local function IsQuestCompletedByPlayer(questID)
	questID = tonumber(questID)
	if not questID or questID <= 0 then return false end
	if C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted then
		local ok, done = pcall(C_QuestLog.IsQuestFlaggedCompleted, questID)
		if ok and done == true then return true end
	elseif IsQuestFlaggedCompleted then
		local ok, done = pcall(IsQuestFlaggedCompleted, questID)
		if ok and done == true then return true end
	end
	return false
end

local function NormalizeObjectiveName(txt)
	if type(txt) ~= "string" then return "" end
	local s = txt:lower()
	-- Strip trailing progress counts like ": 3/10" or "(3/10)" or "3/10"
	s = s:gsub("%s*:%s*%d+%s*/%s*%d+.*$", "")
	s = s:gsub("%s*%(%s*%d+%s*/%s*%d+%s*%)", "")
	s = s:gsub("%s+%d+%s*/%s*%d+.*$", "")
	-- Strip common EN & DE action verbs/suffixes
	s = s:gsub("%s+slain$", ""):gsub("%s+killed$", ""):gsub("%s+defeated$", ""):gsub("%s+collected$", ""):gsub("%s+found$", "")
	s = s:gsub("%s+getötet$", ""):gsub("%s+getoetet$", ""):gsub("%s+besiegt$", ""):gsub("%s+gesammelt$", ""):gsub("%s+erledigt$", ""):gsub("%s+gefunden$", "")
	s = s:gsub("^%s+", ""):gsub("%s+$", "")
	return s
end

local function UnitMatchesObjectiveText(unitName, objText)
	if type(unitName) ~= "string" or unitName == "" or type(objText) ~= "string" or objText == "" then
		return false
	end
	local uLow = unitName:lower():gsub("^%s+", ""):gsub("%s+$", "")
	if #uLow < 3 then return false end
	local oClean = NormalizeObjectiveName(objText)
	if #oClean < 3 then return false end

	if oClean == uLow or oClean:find(uLow, 1, true) or uLow:find(oClean, 1, true) then
		return true
	end
	-- Handle English/German plural forms (e.g. "Wolves" / "Wolf", "Defias Pillagers" / "Defias Pillager", "Wölfe" / "Wolf")
	local uStem = uLow:gsub("ies$", "y"):gsub("ves$", "f"):gsub("es$", ""):gsub("s$", ""):gsub("en$", ""):gsub("er$", "")
	local oStem = oClean:gsub("ies$", "y"):gsub("ves$", "f"):gsub("es$", ""):gsub("s$", ""):gsub("en$", ""):gsub("er$", "")
	if #uStem >= 4 and (oClean:find(uStem, 1, true) or oStem:find(uStem, 1, true)) then
		return true
	end
	if #oStem >= 4 and uLow:find(oStem, 1, true) then
		return true
	end
	-- Multi-word overlap (at least 2 meaningful tokens >= 4 chars match, e.g. "Defias" + "Bandit")
	local uWords, matchCount = {}, 0
	for w in uLow:gmatch("[%a\195\164\195\182\195\188\195\159%-]+") do
		if #w >= 4 then uWords[w] = true end
	end
	for w in oClean:gmatch("[%a\195\164\195\182\195\188\195\159%-]+") do
		if #w >= 4 then
			if uWords[w] then
				matchCount = matchCount + 1
			else
				local ws = w:gsub("s$", ""):gsub("en$", "")
				if #ws >= 4 and uWords[ws] then matchCount = matchCount + 1 end
			end
		end
	end
	return matchCount >= 2
end

function PluribusHiveTooltips:RecordNpcQuestRelation(npcID, npcName, kind, questID, questTitle, questLevel, zone, x, y, broadcast)
	if (not npcID or npcID <= 0) and (not npcName or npcName == "") then return end
	if not questTitle or questTitle == "" then return end
	local idx = EnsureQuestNpcIndex()
	local qid = tonumber(questID) or 0
	local qKey = (qid > 0) and tostring(qid) or ("t:" .. tostring(questTitle):lower())
	local z, cx, cy = zone, tonumber(x), tonumber(y)
	if not z or not cx or not cy then
		z, cx, cy = GetCurrentZoneCoords()
	end

	local function UpsertNpcBucket(key)
		if not key or key == "" then return end
		local rec = idx.npcs[key]
		if not rec then
			rec = { id = tonumber(npcID) or 0, name = npcName or "", zone = z, x = cx, y = cy, starts = {}, ends = {}, objectives = {} }
			idx.npcs[key] = rec
		end
		if npcID and npcID > 0 then rec.id = tonumber(npcID) end
		if npcName and npcName ~= "" then rec.name = npcName end
		if z and z ~= "" then rec.zone = z; rec.x = cx; rec.y = cy end
		rec.starts = rec.starts or {}
		rec.ends = rec.ends or {}
		rec.objectives = rec.objectives or {}
		local targetTbl = (kind == "start" and rec.starts) or (kind == "end" and rec.ends) or rec.objectives
		targetTbl[qKey] = {
			id = qid,
			title = tostring(questTitle),
			level = tonumber(questLevel) or 0,
			seenAt = time(),
		}
	end

	if npcID and tonumber(npcID) and tonumber(npcID) > 0 then
		UpsertNpcBucket("id:" .. tostring(tonumber(npcID)))
	end
	if npcName and npcName ~= "" then
		UpsertNpcBucket("name:" .. tostring(npcName):lower())
	end

	-- Also store quest coordinates for HiveDynamicRoute!
	local qRec = idx.quests[qKey]
	if not qRec then
		qRec = { id = qid, title = tostring(questTitle), level = tonumber(questLevel) or 0 }
		idx.quests[qKey] = qRec
	end
	qRec.title = tostring(questTitle)
	if kind == "start" then
		qRec.startNpc = npcName
		qRec.startZone, qRec.startX, qRec.startY = z, cx, cy
	elseif kind == "end" then
		qRec.endNpc = npcName
		qRec.endZone, qRec.endX, qRec.endY = z, cx, cy
	else
		qRec.objZone, qRec.objX, qRec.objY = z, cx, cy
	end

	-- Share compactly over guild background channel so guildmates passively learn Quest NPCs too
	if broadcast ~= false and _G.PluribusHive and _G.PluribusHive.SendBackground then
		local cleanName = tostring(npcName or ""):gsub("|", "")
		local cleanTitle = tostring(questTitle or ""):gsub("|", "")
		local cleanZone = tostring(z or ""):gsub("|", "")
		local payload = string.format("%s|%d|%s|%d|%s|%d|%s|%.1f|%.1f",
			tostring(kind or "obj"), tonumber(npcID) or 0, cleanName, qid, cleanTitle, tonumber(questLevel) or 0, cleanZone, cx or 50, cy or 50)
		local dedupKey = "QNPC_" .. tostring(kind) .. "_" .. tostring(npcID or cleanName) .. "_" .. qKey
		_G.PluribusHive:SendBackground("QNPC", payload, dedupKey, "GUILD")
	end
end

-- Used by HiveDynamicRoute to get learned Turn-In or Objective coordinates for active quests
function PluribusHiveTooltips:GetLearnedQuestCoords(questID, questTitle, isComplete)
	local idx = EnsureQuestNpcIndex()
	local qid = tonumber(questID) or 0
	local rec = (qid > 0 and idx.quests[tostring(qid)]) or (questTitle and idx.quests["t:" .. tostring(questTitle):lower()]) or nil
	if not rec then return nil, nil, nil end
	if isComplete and rec.endZone and rec.endX and rec.endY then
		return rec.endZone, rec.endX, rec.endY
	end
	if rec.objZone and rec.objX and rec.objY then
		return rec.objZone, rec.objX, rec.objY
	end
	if rec.endZone and rec.endX and rec.endY then
		return rec.endZone, rec.endX, rec.endY
	end
	if rec.startZone and rec.startX and rec.startY then
		return rec.startZone, rec.startX, rec.startY
	end
	return nil, nil, nil
end

function PluribusHiveTooltips:CollectActiveQuestLog()
	local activeById = {}
	local activeByTitle = {}
	local activeList = {}
	if not _G.PluribusUtils or not _G.PluribusUtils.GetQuestLogCount then
		return activeList, activeById, activeByTitle
	end
	local count = _G.PluribusUtils:GetQuestLogCount() or 0
	for i = 1, count do
		local title, level, isHeader, questID, isComplete = _G.PluribusUtils:GetQuestLogEntry(i)
		if title and not isHeader then
			local objs = (_G.PluribusUtils.GetQuestLogObjectives and _G.PluribusUtils:GetQuestLogObjectives(i)) or {}
			local allDone = (isComplete == 1 or isComplete == true)
			if not allDone and #objs > 0 then
				allDone = true
				for _, o in ipairs(objs) do
					if not o.finished then allDone = false; break end
				end
			end
			local qEntry = {
				index = i,
				id = tonumber(questID) or 0,
				title = tostring(title),
				level = tonumber(level) or 0,
				isComplete = allDone,
				objectives = objs,
			}
			table.insert(activeList, qEntry)
			if qEntry.id > 0 then activeById[qEntry.id] = qEntry end
			activeByTitle[qEntry.title:lower()] = qEntry
		end
	end
	return activeList, activeById, activeByTitle
end

-- Query ALL 4 sources for a hovered Mob/NPC: Live Quest Log, Learned Local+Guild Index, Optional QuestieDB, PluribusQuestDB
function PluribusHiveTooltips:GetUnitQuestInfo(unitName, npcID)
	local starts, ends, objectives = {}, {}, {}
	local seenStart, seenEnd, seenObj = {}, {}, {}

	local activeList, activeById, activeByTitle = self:CollectActiveQuestLog()

	local function IsActiveQuest(qid, title)
		if qid and qid > 0 and activeById[qid] then return activeById[qid] end
		if title and activeByTitle[tostring(title):lower()] then return activeByTitle[tostring(title):lower()] end
		return nil
	end

	local function AddStart(qid, title, level)
		if not title or title == "" then return end
		if IsActiveQuest(qid, title) or IsQuestCompletedByPlayer(qid) then return end
		local k = (qid and qid > 0) and tostring(qid) or title:lower()
		if seenStart[k] then return end
		seenStart[k] = true
		table.insert(starts, { id = tonumber(qid) or 0, title = tostring(title), level = tonumber(level) or 0 })
	end

	local function AddEnd(qid, title, level, ready)
		if not title or title == "" then return end
		local k = (qid and qid > 0) and tostring(qid) or title:lower()
		if seenEnd[k] then return end
		seenEnd[k] = true
		table.insert(ends, { id = tonumber(qid) or 0, title = tostring(title), level = tonumber(level) or 0, ready = ready == true })
	end

	local function AddObj(qid, title, progress, finished)
		if not title or title == "" then return end
		local k = ((qid and qid > 0) and tostring(qid) or title:lower()) .. "|" .. tostring(progress or "")
		if seenObj[k] then return end
		seenObj[k] = true
		table.insert(objectives, { id = tonumber(qid) or 0, title = tostring(title), progress = progress or "", finished = finished == true })
	end

	-- 1. Live WoW Quest Log objective matching (works immediately for every active kill/collect quest!)
	if unitName and unitName ~= "" then
		for _, q in ipairs(activeList) do
			for _, obj in ipairs(q.objectives or {}) do
				if obj.text and UnitMatchesObjectiveText(unitName, obj.text) then
					local prog = obj.text:match("(%d+%s*/%s*%d+)") or (obj.finished and "Fertig" or "")
					AddObj(q.id, q.title, prog, obj.finished)
				end
			end
		end
	end

	-- 2. Learned Local + Guild P2P Quest-NPC Knowledge Index
	local idx = EnsureQuestNpcIndex()
	local buckets = {}
	if npcID and tonumber(npcID) and tonumber(npcID) > 0 and idx.npcs["id:" .. tostring(tonumber(npcID))] then
		table.insert(buckets, idx.npcs["id:" .. tostring(tonumber(npcID))])
	end
	if unitName and unitName ~= "" and idx.npcs["name:" .. tostring(unitName):lower()] then
		table.insert(buckets, idx.npcs["name:" .. tostring(unitName):lower()])
	end
	for _, b in ipairs(buckets) do
		for _, q in pairs(b.starts or {}) do
			AddStart(q.id, q.title, q.level)
		end
		for _, q in pairs(b.ends or {}) do
			local act = IsActiveQuest(q.id, q.title)
			if act then
				AddEnd(act.id, act.title, act.level, act.isComplete)
			end
		end
		for _, q in pairs(b.objectives or {}) do
			local act = IsActiveQuest(q.id, q.title)
			if act then
				local prog = ""
				if act.objectives and act.objectives[1] and act.objectives[1].text then
					prog = act.objectives[1].text:match("(%d+%s*/%s*%d+)") or ""
				end
				AddObj(act.id, act.title, prog, act.isComplete)
			end
		end
	end

	-- 3. Optional QuestieDB enrichment (if user has Questie installed alongside Pluribus!)
	if npcID and tonumber(npcID) and tonumber(npcID) > 0 and _G.QuestieDB then
		pcall(function()
			local qdb = _G.QuestieDB
			local npc = (qdb.GetNPC and qdb:GetNPC(npcID)) or (qdb.npcData and qdb.npcData[npcID]) or nil
			if type(npc) == "table" then
				local qStarts = npc.questStarts or npc[11]
				if type(qStarts) == "table" then
					for _, qid in ipairs(qStarts) do
						local qObj = qdb.GetQuest and qdb:GetQuest(qid)
						local qName = (qObj and qObj.name) or (qdb.QueryQuestSingle and qdb.QueryQuestSingle(qid, "name"))
						local qLvl = (qObj and qObj.level) or (qdb.QueryQuestSingle and qdb.QueryQuestSingle(qid, "questLevel")) or 0
						if qName then AddStart(qid, qName, qLvl) end
					end
				end
				local qEnds = npc.questEnds or npc[12]
				if type(qEnds) == "table" then
					for _, qid in ipairs(qEnds) do
						local act = activeById[qid]
						if act then
							AddEnd(act.id, act.title, act.level, act.isComplete)
						end
					end
				end
			end
			-- Check if any active quest's QuestieDB objectives explicitly list this npcID
			if qdb.GetQuest then
				for _, act in ipairs(activeList) do
					if act.id > 0 then
						local qObj = qdb:GetQuest(act.id)
						if qObj and type(qObj.Objectives) == "table" then
							for _, o in ipairs(qObj.Objectives) do
								if o.Id == npcID or (type(o.spawnList) == "table" and o.spawnList[npcID]) then
									local prog = (o.Collected and o.Needed) and (tostring(o.Collected) .. "/" .. tostring(o.Needed)) or ""
									AddObj(act.id, act.title, prog, o.Completed == true)
								end
							end
						end
					end
				end
			end
		end)
	end

	-- 4. PluribusQuestDB fallback (check known quests referencing this NPC/mob name)
	if unitName and unitName ~= "" and _G.PluribusQuestDB and type(_G.PluribusQuestDB.quests) == "table" then
		local uLow = unitName:lower()
		for qid, q in pairs(_G.PluribusQuestDB.quests) do
			if type(q) == "table" and q.name then
				if q.giver and tostring(q.giver):lower() == uLow then
					AddStart(qid, q.name, q.level)
				end
				if q.turnin and tostring(q.turnin):lower() == uLow then
					local act = IsActiveQuest(qid, q.name)
					if act then AddEnd(act.id, act.title, act.level, act.isComplete) end
				end
			end
		end
	end

	return starts, ends, objectives
end

function PluribusHiveTooltips:EnrichUnitTooltip(tooltip, unitToken, explicitGUID)
	if not IsAllowedPlayerTooltip(tooltip) then return end
	if self._enrichingUnit then return end
	if _G.PluribusGearAdvisor and _G.PluribusGearAdvisor._scanningTooltip then return end
	local cfg = PluribusHive and PluribusHive.GetConfig and PluribusHive:GetConfig() or {}
	if cfg.showTooltips == false then return end

	local unit = unitToken
	if not unit and tooltip.GetUnit then
		local ok, _, ttUnit = pcall(tooltip.GetUnit, tooltip)
		if ok and ttUnit then unit = ttUnit end
	end
	if not unit and UnitExists and UnitExists("mouseover") then
		unit = "mouseover"
	end

	-- Never annotate player characters with mob quest info
	if unit and UnitIsPlayer then
		local okP, isPlayer = pcall(UnitIsPlayer, unit)
		if okP and isPlayer then return end
	end

	local unitName = nil
	if unit and UnitName then
		local okN, n = pcall(UnitName, unit)
		if okN and type(n) == "string" and n ~= "" then
			if not (_G.PluribusUtils and _G.PluribusUtils.IsSecret and _G.PluribusUtils:IsSecret(n)) then
				unitName = n
			end
		end
	end
	if not unitName and tooltip.GetName then
		local l1 = _G[tooltip:GetName() .. "TextLeft1"]
		local txt = l1 and l1.GetText and l1:GetText()
		if type(txt) == "string" and txt ~= "" then unitName = txt end
	end

	local guid = explicitGUID
	if not guid and unit and UnitGUID then
		local okG, g = pcall(UnitGUID, unit)
		if okG and type(g) == "string" then guid = g end
	end
	local npcID = ExtractNpcIdFromGUID(guid)
	if not unitName and not npcID then return end

	if TooltipAlreadyHasUnitQuests(tooltip) then return end

	self._enrichingUnit = true
	local okErr = pcall(function()
		local starts, ends, objectives = PluribusHiveTooltips:GetUnitQuestInfo(unitName, npcID)
		if #starts == 0 and #ends == 0 and #objectives == 0 then return end

		tooltip:AddLine(" ")
		local maxPerSection = 4
		for i, q in ipairs(ends) do
			if i > maxPerSection then break end
			local lvlPart = (q.level and q.level > 0) and string.format("[%d] ", q.level) or ""
			local st = q.ready and " |cff4ade80(Fertig)|r" or " |cff94a3b8(Aktiv)|r"
			tooltip:AddDoubleLine("|cff4ade80? " .. L("TT_QUEST_TURNIN") .. "|r", "|cffffffff" .. lvlPart .. q.title .. "|r" .. st, 1, 1, 1, 1, 1, 1)
		end
		for i, q in ipairs(starts) do
			if i > maxPerSection then break end
			local lvlPart = (q.level and q.level > 0) and string.format("[%d] ", q.level) or ""
			tooltip:AddDoubleLine("|cfffbbf24! " .. L("TT_QUEST_GIVER") .. "|r", "|cfffef08a" .. lvlPart .. q.title .. "|r", 1, 1, 1, 1, 1, 1)
		end
		for i, o in ipairs(objectives) do
			if i > maxPerSection then break end
			local progStr = (o.progress and o.progress ~= "")
				and (o.finished and (" |cff4ade80(" .. o.progress .. ")|r") or (" |cfffbbf24(" .. o.progress .. ")|r"))
				or (o.finished and " |cff4ade80(Fertig)|r" or "")
			tooltip:AddDoubleLine("|cff38bdf8• " .. L("TT_QUEST_OBJECTIVE") .. "|r", "|cffe2e8f0" .. o.title .. "|r" .. progStr, 1, 1, 1, 1, 1, 1)
		end
		tooltip._plbInjectedUnit = tostring(npcID or unitName)
		tooltip:Show()
	end)
	self._enrichingUnit = false
	if not okErr and PluribusUtils and PluribusUtils.Debug then
		PluribusUtils:Debug("Unit tooltip enrich skipped", "Tooltips")
	end
end

function PluribusHiveTooltips:InitializeQuestNpcLearner()
	if self._learnerInit then return end
	self._learnerInit = true

	-- Receive guildmates' discovered Quest NPCs via Hive P2P!
	if _G.PluribusHive and _G.PluribusHive.RegisterHandler then
		_G.PluribusHive:RegisterHandler("QNPC", function(_, body)
			local kind, npcIdStr, npcName, qidStr, qTitle, qLvlStr, z, xStr, yStr =
				tostring(body or ""):match("^([^|]+)|(%d+)|([^|]*)|(%d+)|([^|]+)|(%d+)|([^|]*)|([^|]*)|?(.*)$")
			if kind and qTitle and qTitle ~= "" then
				PluribusHiveTooltips:RecordNpcQuestRelation(
					tonumber(npcIdStr), npcName, kind, tonumber(qidStr), qTitle, tonumber(qLvlStr),
					z, tonumber(xStr), tonumber(yStr), false
				)
			end
		end)
	end

	local function GetCurrentNpcIdentity()
		local unit = (UnitExists and UnitExists("npc")) and "npc" or ((UnitExists and UnitExists("target")) and "target" or nil)
		if not unit then return nil, nil end
		if UnitIsPlayer and UnitIsPlayer(unit) then return nil, nil end
		local name = UnitName and UnitName(unit)
		local guid = UnitGUID and UnitGUID(unit)
		return ExtractNpcIdFromGUID(guid), name
	end

	local function SnapshotObjectives()
		local snap = {}
		local activeList = PluribusHiveTooltips:CollectActiveQuestLog()
		for _, q in ipairs(activeList) do
			for idx, o in ipairs(q.objectives or {}) do
				local cur = tonumber((o.text or ""):match("(%d+)%s*/%s*%d+")) or (o.finished and 1 or 0)
				snap[tostring(q.id) .. ":" .. tostring(q.title) .. ":" .. tostring(idx)] = {
					cur = cur, id = q.id, title = q.title, level = q.level,
				}
			end
		end
		return snap
	end

	self._lastObjSnapshot = SnapshotObjectives()

	local f = CreateFrame("Frame")
	for _, ev in ipairs({
		"QUEST_DETAIL",
		"QUEST_GREETING",
		"GOSSIP_SHOW",
		"QUEST_PROGRESS",
		"QUEST_COMPLETE",
		"QUEST_LOG_UPDATE",
		"PLAYER_TARGET_CHANGED",
		"UNIT_DIED",
	}) do
		pcall(f.RegisterEvent, f, ev)
	end
	f:SetScript("OnEvent", function(_, ev)
		if ev == "PLAYER_TARGET_CHANGED" then
			if UnitExists and UnitExists("target") and not (UnitIsPlayer and UnitIsPlayer("target")) then
				local n = UnitName and UnitName("target")
				local nid = ExtractNpcIdFromGUID(UnitGUID and UnitGUID("target"))
				if n and n ~= "" then
					PluribusHiveTooltips._lastTargetMob = { id = nid, name = n, at = (GetTime and GetTime()) or 0 }
				end
			end
		elseif ev == "QUEST_DETAIL" then
			local nid, nName = GetCurrentNpcIdentity()
			local qTitle = GetTitleText and GetTitleText()
			local qid = (GetQuestID and GetQuestID()) or 0
			if nName and qTitle and qTitle ~= "" then
				PluribusHiveTooltips:RecordNpcQuestRelation(nid, nName, "start", qid, qTitle, 0)
			end
		elseif ev == "QUEST_GREETING" then
			local nid, nName = GetCurrentNpcIdentity()
			if nName then
				local numAvail = (GetNumAvailableQuests and GetNumAvailableQuests()) or 0
				for i = 1, numAvail do
					local qTitle = GetAvailableTitle and GetAvailableTitle(i)
					if qTitle and qTitle ~= "" then
						PluribusHiveTooltips:RecordNpcQuestRelation(nid, nName, "start", 0, qTitle, 0)
					end
				end
				local numActive = (GetNumActiveQuests and GetNumActiveQuests()) or 0
				for i = 1, numActive do
					local qTitle = GetActiveTitle and GetActiveTitle(i)
					if qTitle and qTitle ~= "" then
						PluribusHiveTooltips:RecordNpcQuestRelation(nid, nName, "end", 0, qTitle, 0)
					end
				end
			end
		elseif ev == "GOSSIP_SHOW" then
			local nid, nName = GetCurrentNpcIdentity()
			if nName then
				if C_GossipInfo and C_GossipInfo.GetAvailableQuests then
					local ok, avail = pcall(C_GossipInfo.GetAvailableQuests)
					if ok and type(avail) == "table" then
						for _, q in ipairs(avail) do
							if q.title then
								PluribusHiveTooltips:RecordNpcQuestRelation(nid, nName, "start", q.questID or 0, q.title, q.questLevel or 0)
							end
						end
					end
				end
				if C_GossipInfo and C_GossipInfo.GetActiveQuests then
					local ok, act = pcall(C_GossipInfo.GetActiveQuests)
					if ok and type(act) == "table" then
						for _, q in ipairs(act) do
							if q.title then
								PluribusHiveTooltips:RecordNpcQuestRelation(nid, nName, "end", q.questID or 0, q.title, q.questLevel or 0)
							end
						end
					end
				end
			end
		elseif ev == "QUEST_PROGRESS" or ev == "QUEST_COMPLETE" then
			local nid, nName = GetCurrentNpcIdentity()
			local qTitle = GetTitleText and GetTitleText()
			local qid = (GetQuestID and GetQuestID()) or 0
			if nName and qTitle and qTitle ~= "" then
				PluribusHiveTooltips:RecordNpcQuestRelation(nid, nName, "end", qid, qTitle, 0)
			end
		elseif ev == "QUEST_LOG_UPDATE" then
			-- Correlate recent mob target with any quest objective counter that just incremented!
			local nowSnap = SnapshotObjectives()
			local prev = PluribusHiveTooltips._lastObjSnapshot or {}
			local mob = PluribusHiveTooltips._lastTargetMob
			local now = (GetTime and GetTime()) or 0
			if mob and mob.name and (now - (mob.at or 0)) <= 6.0 then
				for k, curInfo in pairs(nowSnap) do
					local pInfo = prev[k]
					if pInfo and curInfo.cur > pInfo.cur then
						PluribusHiveTooltips:RecordNpcQuestRelation(mob.id, mob.name, "obj", curInfo.id, curInfo.title, curInfo.level)
					end
				end
			end
			PluribusHiveTooltips._lastObjSnapshot = nowSnap
		end
	end)
end

function PluribusHiveTooltips:EnrichItemTooltip(tooltip, itemID, stackCount, itemLink)
	itemID = tonumber(itemID)
	if not IsAllowedPlayerTooltip(tooltip) or not itemID or itemID <= 0 then return end
	if self._enriching then return end
	if _G.PluribusGearAdvisor and _G.PluribusGearAdvisor._scanningTooltip then return end
	local cfg = PluribusHive:GetConfig()
	if cfg.showTooltips == false then return end

	-- Prevent duplicate injection on the exact same rendered tooltip pass (never gets stuck across rebuilds!)
	if TooltipAlreadyHasPluribus(tooltip) then
		return
	end
	tooltip._plbInjectedItem = itemID
	self._enriching = true
	local okErr, errMsg = pcall(self._DoEnrichItemTooltip, self, tooltip, itemID, stackCount, itemLink, cfg)
	self._enriching = false
	if not okErr and PluribusUtils and PluribusUtils.Debug then
		PluribusUtils:Debug("Tooltip enrich skipped: " .. tostring(errMsg), "Tooltips")
	end
end

function PluribusHiveTooltips:_DoEnrichItemTooltip(tooltip, itemID, stackCount, itemLink, cfg)
	local lines = {}

	-- 1. You / Alts / Guild Bag + Bank Counts
	if cfg.showTooltipCounts and _G.PluribusHiveInventory then
		local c = _G.PluribusHiveInventory:GetItemCounts(itemID)
		if c then
			local myTotal = (c.selfBags or 0) + (c.selfBank or 0)
			local segs = {}
			if myTotal > 0 then
				if (c.selfBank or 0) > 0 then
					table.insert(segs, string.format("You: %d (%d bag, %d bank)", myTotal, c.selfBags, c.selfBank))
				else
					table.insert(segs, string.format("You: %d", myTotal))
				end
			end
			local MAX_HOLDERS = 3
			if (c.totalAlts or 0) > 0 then
				local altNames = {}
				for i, a in ipairs(c.alts) do
					if i <= MAX_HOLDERS then table.insert(altNames, a.name .. "(" .. a.total .. ")") end
				end
				if #c.alts > MAX_HOLDERS then table.insert(altNames, "+" .. (#c.alts - MAX_HOLDERS) .. " more") end
				table.insert(segs, "Alts: " .. table.concat(altNames, ", "))
			end
			if (c.totalGuild or 0) > 0 then
				local gNames = {}
				for i, g in ipairs(c.guild) do
					if i <= MAX_HOLDERS then table.insert(gNames, g.name .. "(" .. g.total .. ")") end
				end
				if #c.guild > MAX_HOLDERS then table.insert(gNames, "+" .. (#c.guild - MAX_HOLDERS) .. " more") end
				local gHdr = (#c.guild > MAX_HOLDERS) and ("Guild(" .. c.totalGuild .. "): ") or "Guild: "
				table.insert(segs, gHdr .. table.concat(gNames, ", "))
			end
			if #segs > 0 then
				table.insert(lines, {
					left = "|cff38bdf8Hive Bags:|r",
					right = "|cffe2e8f0" .. table.concat(segs, "  ·  ") .. "|r",
				})
			end
		end
	end

	-- 2. Guild Profession Needs (with emerald highlight when YOU don't need it!)
	if cfg.showTooltipProfNeeds and _G.PluribusHiveProfessions then
		local neededBy, isSurplus = _G.PluribusHiveProfessions:GetGuildNeedsForItem(itemID)
		if #neededBy > 0 then
			local who = {}
			local MAX_NEEDS = 3
			for i, n in ipairs(neededBy) do
				if i <= MAX_NEEDS then
					local lvlPart = (n.level and n.level > 0) and (" " .. n.level) or ""
					table.insert(who, string.format("%s (%s%s)", n.name, n.prof, lvlPart))
				end
			end
			if #neededBy > MAX_NEEDS then
				table.insert(who, "+" .. (#neededBy - MAX_NEEDS) .. " more")
			end
			if isSurplus then
				table.insert(lines, {
					left = "|cff4ade80Guild Needs (Surplus!):|r",
					right = "|cffbbf7d0" .. table.concat(who, ", ") .. "|r",
				})
			else
				table.insert(lines, {
					left = "|cff93c5fdGuild Also Needs:|r",
					right = "|cffcbd5e1" .. table.concat(who, ", ") .. "|r",
				})
			end
		end
	end

	-- 3. Guild-Synced AH Market Price (always displays unit + stack price, or vendor/scan status)
	if cfg.showTooltipPrices ~= false and _G.PluribusHiveAuction then
		local price = _G.PluribusHiveAuction:GetPrice(itemID)
		local qty = tonumber(stackCount) or 1
		if price and price.copper and price.copper > 0 then
			local age = FormatAge(price.seenAt)
			local agePart = age ~= "" and (" |cff94a3b8(" .. age .. ")|r") or ""
			local stackPart = (qty > 1) and (" |cffcbd5e1(x" .. qty .. ": " .. PluribusUtils:FormatGold(price.copper * qty) .. ")|r") or ""
			table.insert(lines, {
				left = "|cfffbbf24AH Price:|r",
				right = "|cfffef08a" .. PluribusUtils:FormatGold(price.copper) .. "|r" .. stackPart .. agePart,
			})
		elseif HasAnyScannedAHPrices() then
			table.insert(lines, {
				left = "|cfffbbf24AH Price:|r",
				right = "|cff94a3b8No AH listings|r",
			})
		else
			table.insert(lines, {
				left = "|cfffbbf24AH Price:|r",
				right = "|cff94a3b8Open AH to auto-scan|r",
			})
		end
		-- Also show Vendor Sell Value if item has one (handy for vendor-vs-AH decisions)
		local sellPrice = select(11, PluribusUtils:GetItemInfo(itemID))
		if tonumber(sellPrice) and tonumber(sellPrice) > 0 then
			local vQty = (qty > 1) and (" |cff94a3b8(x" .. qty .. ": " .. PluribusUtils:FormatGold(sellPrice * qty) .. ")|r") or ""
			table.insert(lines, {
				left = "|cff94a3b8Vendor:|r",
				right = "|cffcbd5e1" .. PluribusUtils:FormatGold(sellPrice) .. "|r" .. vQty,
			})
		end
		-- Show Mean Disenchant Value for equippable green/blue/epic items
		if _G.PluribusHiveAuctionator and _G.PluribusHiveAuctionator.CalculateMeanDisenchantValue then
			local deInfo = _G.PluribusHiveAuctionator:CalculateMeanDisenchantValue(itemID)
			if deInfo and deInfo.meanCopper and deInfo.meanCopper > 0 then
				local dealTag = (price and price.copper and price.copper > 0 and price.copper < deInfo.meanCopper)
					and " |cff4ade80(DE Deal!)|r" or ""
				table.insert(lines, {
					left = "|cffa855f7Ø Entzaubern:|r",
					right = "|cffd8b4fe" .. PluribusUtils:FormatGold(deInfo.meanCopper) .. "|r" .. dealTag,
				})
			end
		end
	end

	-- 3b. Custom Trash Auto-Sell indicator
	if _G.PluribusHiveInventory and _G.PluribusHiveInventory.IsCustomTrash and _G.PluribusHiveInventory:IsCustomTrash(itemID) then
		table.insert(lines, {
			left = "|cfff97316Trash (Auto-Verkauf):|r",
			right = "|cfffdba74Wird beim Händler verkauft (Alt+Klick: aus)|r",
		})
	end

	-- 4. Wowhead / Guild P2P Network Game Data (on-demand P2P lookup on miss)
	if cfg.showTooltipGameDB and _G.PluribusHiveNetworkDB then
		local entry = _G.PluribusHiveNetworkDB:GetItem(itemID)
		if entry and entry.source and entry.source ~= "" then
			table.insert(lines, {
				left = "|cff94a3b8Hive DB:|r",
				right = "|cffcbd5e1" .. entry.source:sub(1, 56) .. "|r",
			})
		else
			_G.PluribusHiveNetworkDB:RequestItem(itemID)
		end
	end

	-- 5. Pluribus GearAdvisor: % Upgrade/Downgrade, Cap Guardian warnings & Alt BoE checks
	if cfg.showGearJudgeTooltips ~= false and _G.PluribusHiveGearJudge and _G.PluribusHiveGearJudge.EvaluateItem then
		local ttLink = itemLink
		if not ttLink and tooltip.GetItem then
			local ok, _, linkFromTT = pcall(tooltip.GetItem, tooltip)
			if ok and linkFromTT then ttLink = linkFromTT end
		end
		local eval = _G.PluribusHiveGearJudge:EvaluateItem(ttLink or itemID)
		if eval and eval.equippable then
			local L = _G.PluribusL
			local pct = tonumber(eval.pctDelta or eval.pct) or 0
			local verdictStr
			if eval.isEquipped then
				verdictStr = "|cff94a3b8" .. (L and L:Get("GEAR_SIDEGRADE") or "Equipped") .. "|r"
			elseif math.abs(pct) < 0.25 then
				verdictStr = "|cff94a3b8" .. (L and L:Get("GEAR_SIDEGRADE") or "Sidegrade") .. " (0.0%)|r"
			elseif pct > 0 then
				verdictStr = string.format("|cff4ade80+%.1f%% %s|r |cff94a3b8(%s)|r", pct, L and L:Get("GEAR_UPGRADE") or "Upgrade", tostring(eval.specName or "Spec"))
			else
				verdictStr = string.format("|cfff87171%.1f%% %s|r |cff94a3b8(%s)|r", pct, L and L:Get("GEAR_DOWNGRADE") or "Downgrade", tostring(eval.specName or "Spec"))
			end
			table.insert(lines, {
				left = "|cff38bdf8" .. (L and L:Get("GEAR_TOOLTIP_LABEL") or "GearAdvisor:") .. "|r",
				right = verdictStr,
			})
			if eval.capWarning and eval.capWarning ~= "" then
				table.insert(lines, {
					left = "|cfffbbf24" .. (L and L:Get("GEAR_CAP_LABEL") or "Cap Guardian:") .. "|r",
					right = "|cfffef08a" .. tostring(eval.capWarning) .. "|r",
				})
			end
			if _G.PluribusHiveGearJudge.GetAltUpgradesForItem then
				local alts = _G.PluribusHiveGearJudge:GetAltUpgradesForItem(ttLink or itemID)
				if alts and #alts > 0 then
					local altParts = {}
					local MAX_ALT_BOE = 3
					for idx, a in ipairs(alts) do
						if idx <= MAX_ALT_BOE then
							table.insert(altParts, string.format("%s (+%.1f%%)", tostring(a.name or "Alt"), tonumber(a.pct) or 0))
						end
					end
					if #alts > MAX_ALT_BOE then
						table.insert(altParts, "+" .. tostring(#alts - MAX_ALT_BOE) .. " more")
					end
					table.insert(lines, {
						left = "|cffc084fc" .. (L and L:Get("GEAR_ALT_BOE") or "Alt BoE Upgrade:") .. "|r",
						right = "|cffe9d5ff" .. table.concat(altParts, ", ") .. "|r",
					})
				end
			end
		end
	end

	if #lines == 0 then return end

	tooltip:AddLine(" ")
	for _, ln in ipairs(lines) do
		tooltip:AddDoubleLine(ln.left, ln.right, 1, 1, 1, 1, 1, 1)
	end
	tooltip:Show()
end

local function EnrichFromTooltipGetItem(tt, fallbackID, fallbackCount, fallbackLink)
	if not tt then return end
	local link = fallbackLink
	local itemID = tonumber(fallbackID)
	if (not itemID or not link) and tt.GetItem then
		local ok, _, ttLink = pcall(tt.GetItem, tt)
		if ok and ttLink then
			link = link or ttLink
			itemID = itemID or (PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(ttLink))
		end
	end
	if itemID and itemID > 0 then
		PluribusHiveTooltips:EnrichItemTooltip(tt, itemID, fallbackCount, link)
	end
end

local function GetBagSlotItemInfo(bag, slot)
	if C_Container and C_Container.GetContainerItemInfo then
		local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
		if ok and type(info) == "table" then
			return info.itemID, info.stackCount, info.hyperlink
		end
	end
	local id = GetContainerItemID and GetContainerItemID(bag, slot) or nil
	local link = GetContainerItemLink and GetContainerItemLink(bag, slot) or nil
	local cnt = 1
	if GetContainerItemInfo then
		local _, c = GetContainerItemInfo(bag, slot)
		cnt = tonumber(c) or 1
	end
	if not id and link and PluribusUtils then
		id = PluribusUtils:GetItemIDFromHyperlink(link)
	end
	return id, cnt, link
end

function PluribusHiveTooltips:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:InitializeQuestNpcLearner()

	-- 1. Modern TooltipDataProcessor hooks (Items + Units/Mobs/NPCs — strictly ignores hidden scanner tooltips!)
	if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
		if Enum.TooltipDataType.Item then
			pcall(function()
				TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
					if not IsAllowedPlayerTooltip(tooltip) or not data then return end
					if PluribusHiveTooltips._enriching then return end
					if _G.PluribusGearAdvisor and _G.PluribusGearAdvisor._scanningTooltip then return end
					local itemID = data.id
					local link = data.hyperlink
					if not itemID and tooltip.GetItem then
						local ok, _, ttLink = pcall(tooltip.GetItem, tooltip)
						if ok and ttLink then
							link = link or ttLink
							itemID = PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(ttLink)
						end
					end
					if itemID then
						PluribusHiveTooltips:EnrichItemTooltip(tooltip, itemID, nil, link)
					end
				end)
			end)
		end
		if Enum.TooltipDataType.Unit then
			pcall(function()
				TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
					if not IsAllowedPlayerTooltip(tooltip) then return end
					local guid = data and data.guid
					PluribusHiveTooltips:EnrichUnitTooltip(tooltip, nil, guid)
				end)
			end)
		end
	end

	-- 2. Classic / Warcraft Forever GameTooltip & ItemRefTooltip script hooks + direct method hooks
	local function HookTooltip(tt)
		if not tt then return end
		if tt.HookScript then
			pcall(tt.HookScript, tt, "OnTooltipCleared", function(selfTT)
				selfTT._plbInjectedItem = nil
				selfTT._plbInjectedUnit = nil
			end)
			pcall(tt.HookScript, tt, "OnHide", function(selfTT)
				selfTT._plbInjectedItem = nil
				selfTT._plbInjectedUnit = nil
			end)
			pcall(tt.HookScript, tt, "OnTooltipSetItem", function(selfTT)
				EnrichFromTooltipGetItem(selfTT)
			end)
			pcall(tt.HookScript, tt, "OnTooltipSetUnit", function(selfTT)
				PluribusHiveTooltips:EnrichUnitTooltip(selfTT)
			end)
			pcall(tt.HookScript, tt, "OnShow", function(selfTT)
				EnrichFromTooltipGetItem(selfTT)
				if selfTT == _G.GameTooltip and selfTT.GetUnit then
					local ok, _, u = pcall(selfTT.GetUnit, selfTT)
					if ok and u then
						PluribusHiveTooltips:EnrichUnitTooltip(selfTT, u)
					end
				end
			end)
		end

		if hooksecurefunc then
			if tt == _G.GameTooltip and tt.SetUnit then
				pcall(hooksecurefunc, tt, "SetUnit", function(selfTT, unit)
					PluribusHiveTooltips:EnrichUnitTooltip(selfTT, unit)
				end)
			end
			if tt.SetBagItem then
				pcall(hooksecurefunc, tt, "SetBagItem", function(selfTT, bag, slot)
					local id, cnt, link = GetBagSlotItemInfo(bag, slot)
					EnrichFromTooltipGetItem(selfTT, id, cnt, link)
				end)
			end
			if tt.SetInventoryItem then
				pcall(hooksecurefunc, tt, "SetInventoryItem", function(selfTT, unit, slot)
					local id = GetInventoryItemID and GetInventoryItemID(unit, slot) or nil
					local link = GetInventoryItemLink and GetInventoryItemLink(unit, slot) or nil
					local cnt = GetInventoryItemCount and GetInventoryItemCount(unit, slot) or 1
					EnrichFromTooltipGetItem(selfTT, id, cnt, link)
				end)
			end
			if tt.SetItemByID then
				pcall(hooksecurefunc, tt, "SetItemByID", function(selfTT, itemID)
					if itemID then
						PluribusHiveTooltips:EnrichItemTooltip(selfTT, itemID)
					end
				end)
			end
			if tt.SetHyperlink then
				pcall(hooksecurefunc, tt, "SetHyperlink", function(selfTT, link)
					local itemID = link and PluribusUtils and PluribusUtils:GetItemIDFromHyperlink(link)
					if itemID then
						PluribusHiveTooltips:EnrichItemTooltip(selfTT, itemID, nil, link)
					else
						EnrichFromTooltipGetItem(selfTT)
					end
				end)
			end
			for _, methodName in ipairs({
				"SetAuctionItem",
				"SetTradeSkillItem",
				"SetMerchantItem",
				"SetLootItem",
				"SetInboxItem",
				"SetQuestItem",
				"SetCraftItem",
				"SetGuildBankItem",
			}) do
				if tt[methodName] then
					pcall(hooksecurefunc, tt, methodName, function(selfTT)
						EnrichFromTooltipGetItem(selfTT)
					end)
				end
			end
		end
	end

	HookTooltip(_G.GameTooltip)
	HookTooltip(_G.ItemRefTooltip)
	HookTooltip(_G.ShoppingTooltip1)
	HookTooltip(_G.ShoppingTooltip2)
end

return PluribusHiveTooltips
