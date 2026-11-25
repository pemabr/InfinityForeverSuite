-- PluribusHive Guild Transit Navigation Module
-- Identifies online guild Mages (capital portals) and Warlocks (Ritual of Summoning)
-- who are currently in the open world (NOT inside a dungeon, raid, or battleground instance)
-- and injects them as dynamic transit edges into PluribusHivePathfinder.
-- Warlock summons carry a helper-finding coordination penalty (2 click helpers needed),
-- scaled down when other open-world guildmates are already in the Warlock's zone.

PluribusHiveGuildTransit = {
	initialized = false,
	lastSummary = { mages = 0, warlocks = 0, skippedInstanced = 0 },
}
_G.PluribusHiveGuildTransit = PluribusHiveGuildTransit

-- Tunable real-world transit timing model (seconds)
PluribusHiveGuildTransit.COSTS = {
	PORTAL_BASE_SEC            = 45, -- Whisper + invite + 10s cast + load screen (solo Mage)
	PORTAL_NO_GPS_PENALTY_SEC  = 15, -- Mage seen via guild roster only (no exact x/y GPS)
	SUMMON_BASE_SEC            = 60, -- Whisper + group + ritual cast + load screen
	SUMMON_HELPER_PENALTY_0    = 95, -- 0 other guildmates in zone -> must find 2 random clickers
	SUMMON_HELPER_PENALTY_1    = 65, -- 1 other guildmate in zone -> still need 1 extra clicker
	SUMMON_HELPER_PENALTY_2    = 35, -- 2+ other guildmates in zone -> mild coordination buffer
	SUMMON_NO_GPS_PENALTY_SEC  = 15, -- Warlock seen via guild roster only (no exact x/y GPS)
}

PluribusHiveGuildTransit.MAGE_MIN_LEVEL = 40
PluribusHiveGuildTransit.WARLOCK_MIN_LEVEL = 20

-- Classic WoW Mage Portal unlocks by faction & level
PluribusHiveGuildTransit.MAGE_PORTALS = {
	ALLIANCE = {
		{ nodeId = "sw_gate",   destLabel = "Stormwind City", minLevel = 40, spell = "Portal: Stormwind", spellDE = "Portal: Sturmwind" },
		{ nodeId = "ironforge", destLabel = "Ironforge",      minLevel = 40, spell = "Portal: Ironforge", spellDE = "Portal: Eisenschmiede" },
		{ nodeId = "darnassus", destLabel = "Darnassus",      minLevel = 50, spell = "Portal: Darnassus", spellDE = "Portal: Darnassus" },
	},
	HORDE = {
		{ nodeId = "org_zep",       destLabel = "Orgrimmar",     minLevel = 40, spell = "Portal: Orgrimmar",     spellDE = "Portal: Orgrimmar" },
		{ nodeId = "uc_zep",        destLabel = "Undercity",     minLevel = 40, spell = "Portal: Undercity",     spellDE = "Portal: Unterstadt" },
		{ nodeId = "thunder_bluff", destLabel = "Thunder Bluff", minLevel = 50, spell = "Portal: Thunder Bluff", spellDE = "Portal: Donnerfels" },
	},
}

-- Direct mapping from canonical city zone names to Pathfinder graph hub node IDs
PluribusHiveGuildTransit.CITY_TO_NODE = {
	["Stormwind City"] = "sw_gate",
	["Ironforge"]      = "ironforge",
	["Darnassus"]      = "darnassus",
	["Teldrassil"]     = "darnassus",
	["Orgrimmar"]      = "org_zep",
	["Undercity"]      = "uc_zep",
	["Thunder Bluff"]  = "thunder_bluff",
}

-- Comprehensive Classic WoW Dungeon, Raid & Battleground zone denylist (EN + DE)
-- Used both as primary filter for roster-only guildmates AND as fallback alongside live PING inInstance flags.
PluribusHiveGuildTransit.INSTANCE_ZONES = {
	-- Classic Raids (EN)
	["molten core"] = true,
	["blackwing lair"] = true,
	["onyxia's lair"] = true,
	["zul'gurub"] = true,
	["ruins of ahn'qiraj"] = true,
	["temple of ahn'qiraj"] = true,
	["ahn'qiraj"] = true,
	["ahn'qiraj temple"] = true,
	["naxxramas"] = true,
	-- Classic Raids (DE)
	["geschmolzener kern"] = true,
	["der geschmolzene kern"] = true,
	["pechschwingenhort"] = true,
	["onyxias hort"] = true,
	["ruinen von ahn'qiraj"] = true,
	["tempel von ahn'qiraj"] = true,
	-- Classic Dungeons (EN)
	["ragefire chasm"] = true,
	["wailing caverns"] = true,
	["the deadmines"] = true,
	["deadmines"] = true,
	["shadowfang keep"] = true,
	["blackfathom deeps"] = true,
	["the stockade"] = true,
	["stockade"] = true,
	["gnomeregan"] = true,
	["razorfen kraul"] = true,
	["scarlet monastery"] = true,
	["razorfen downs"] = true,
	["uldaman"] = true,
	["zul'farrak"] = true,
	["maraudon"] = true,
	["the temple of atal'hakkar"] = true,
	["temple of atal'hakkar"] = true,
	["sunken temple"] = true,
	["blackrock depths"] = true,
	["blackrock spire"] = true,
	["lower blackrock spire"] = true,
	["upper blackrock spire"] = true,
	["dire maul"] = true,
	["stratholme"] = true,
	["scholomance"] = true,
	-- Classic Dungeons (DE)
	["der flammenschlund"] = true,
	["flammenschlund"] = true,
	["die höhlen des wehklagens"] = true,
	["höhlen des wehklagens"] = true,
	["die todesminen"] = true,
	["todesminen"] = true,
	["burg schattenfang"] = true,
	["tiefschwarze grotte"] = true,
	["das verlies"] = true,
	["verlies"] = true,
	["kral der klingenhauer"] = true,
	["das scharlachrote kloster"] = true,
	["scharlachrotes kloster"] = true,
	["hügel der klingenhauer"] = true,
	["der tempel von atal'hakkar"] = true,
	["tempel von atal'hakkar"] = true,
	["versunkener tempel"] = true,
	["schwarzfelstiefen"] = true,
	["schwarzfelsspitze"] = true,
	["obere schwarzfelsspitze"] = true,
	["untere schwarzfelsspitze"] = true,
	["düsterbruch"] = true,
	-- Battlegrounds (EN + DE — cannot portal/summon open-world players from inside a BG)
	["warsong gulch"] = true,
	["arathi basin"] = true,
	["alterac valley"] = true,
	["kriegshymnenschlucht"] = true,
	["arathibecken"] = true,
	["alteractal"] = true,
}

local INSTANCE_SUBSTRINGS = {
	"blackwing", "molten core", "geschmolzener kern", "pechschwingen",
	"onyxia", "naxxramas", "zul'gurub", "ahn'qiraj",
	"stratholme", "scholomance", "dire maul", "düsterbruch",
	"blackrock depths", "schwarzfelstiefen", "blackrock spire", "schwarzfelsspitze",
	"scarlet monastery", "scharlachrote", "scharlachrotes kloster",
	"deadmines", "todesminen", "wailing caverns", "höhlen des wehklagens",
	"shadowfang", "schattenfang", "blackfathom", "tiefschwarze grotte",
	"gnomeregan", "uldaman", "zul'farrak", "maraudon", "atal'hakkar",
	"razorfen", "klingenhauer", "ragefire", "flammenschlund", "stockade", "verlies",
	"warsong gulch", "kriegshymnenschlucht", "arathi basin", "arathibecken",
	"alterac valley", "alteractal",
}

local function TrimLower(str)
	if not str then return "" end
	return (tostring(str):lower():match("^%s*(.-)%s*$") or "")
end

function PluribusHiveGuildTransit:NormalizeClass(classFile, classDisplay)
	local raw = TrimLower(classFile)
	if raw == "" then raw = TrimLower(classDisplay) end
	if raw == "mage" or raw == "magier" or raw == "magierin" then
		return "MAGE"
	elseif raw == "warlock" or raw == "hexenmeister" or raw == "hexenmeisterin" then
		return "WARLOCK"
	end
	if classFile and classFile ~= "" then
		return tostring(classFile):upper()
	end
	return raw:upper()
end

-- Returns true if the member's zone or live status indicates a Dungeon, Raid, or Battleground instance.
function PluribusHiveGuildTransit:IsInstanceZone(zoneName)
	local low = TrimLower(zoneName)
	if low == "" then return false end
	if self.INSTANCE_ZONES[low] then return true end
	for _, pat in ipairs(INSTANCE_SUBSTRINGS) do
		if low:find(pat, 1, true) then
			return true
		end
	end
	return false
end

function PluribusHiveGuildTransit:IsMemberInInstance(member)
	if not member then return true end
	if member.inInstance == true then return true end
	if member.instanceType and member.instanceType ~= "" and member.instanceType ~= "none" then
		return true
	end
	if self:IsInstanceZone(member.zone) then
		return true
	end
	return false
end

function PluribusHiveGuildTransit:ResolveMemberNode(zone, x, y, faction)
	local pf = _G.PluribusHivePathfinder
	if not pf then return nil, zone end
	local canon = pf.CanonicalZone and pf:CanonicalZone(zone) or zone
	local cityNode = self.CITY_TO_NODE[canon]
	if cityNode and pf.NODES and pf.NODES[cityNode] then
		local n = pf.NODES[cityNode]
		if n.faction == "NEUTRAL" or n.faction == faction then
			return cityNode, canon
		end
	end
	local nx = (tonumber(x) and tonumber(x) > 0) and (tonumber(x) <= 1 and tonumber(x) * 100 or tonumber(x)) or 50
	local ny = (tonumber(y) and tonumber(y) > 0) and (tonumber(y) <= 1 and tonumber(y) * 100 or tonumber(y)) or 50
	if pf.FindNearestNode then
		local nodeId = pf:FindNearestNode(canon, nx, ny, faction)
		if nodeId then
			return nodeId, canon
		end
	end
	return nil, canon
end

-- Computes Warlock summon total cost + helper-finding penalty based on nearby open-world guildmates.
function PluribusHiveGuildTransit:EstimateWarlockSummonCost(nearbyHelpers, hasLiveGPS)
	local c = self.COSTS
	local helpers = math.max(0, math.floor(tonumber(nearbyHelpers) or 0))
	local helperPenalty
	if helpers >= 2 then
		helperPenalty = c.SUMMON_HELPER_PENALTY_2
	elseif helpers == 1 then
		helperPenalty = c.SUMMON_HELPER_PENALTY_1
	else
		helperPenalty = c.SUMMON_HELPER_PENALTY_0
	end
	local gpsPenalty = hasLiveGPS and 0 or c.SUMMON_NO_GPS_PENALTY_SEC
	return c.SUMMON_BASE_SEC + helperPenalty + gpsPenalty, helperPenalty
end

function PluribusHiveGuildTransit:EstimateMagePortalCost(hasLiveGPS)
	local c = self.COSTS
	return c.PORTAL_BASE_SEC + (hasLiveGPS and 0 or c.PORTAL_NO_GPS_PENALTY_SEC)
end

-- Returns eligible open-world guild Mages & Warlocks plus instanced skip telemetry.
-- opts.guildMembers can be supplied for deterministic simulation/testing.
function PluribusHiveGuildTransit:GetEligibleProviders(opts)
	opts = opts or {}
	local pf = _G.PluribusHivePathfinder
	local faction = opts.faction or (pf and pf.GetPlayerFaction and pf:GetPlayerFaction()) or "ALLIANCE"
	local roster = opts.guildMembers
	if not roster then
		if _G.PluribusHive and _G.PluribusHive.GetGuildMemberRoster then
			local ok, r = pcall(_G.PluribusHive.GetGuildMemberRoster, _G.PluribusHive)
			if ok and type(r) == "table" then
				roster = r
			end
		end
	end
	roster = roster or {}

	local meName = opts.selfName or (_G.PluribusHive and _G.PluribusHive.GetPlayerShortName and _G.PluribusHive:GetPlayerShortName()) or ""
	local meKey = TrimLower(meName)

	-- Pass 1: Count open-world online guildmates per canonical zone (for Warlock 2-helper penalty scaling)
	local openGuildByZone = {}
	for _, m in ipairs(roster) do
		local isOnline = (m.online == true or m.online == 1)
		local mKey = TrimLower(m.canonKey or m.name)
		local isSelf = (m.isSelf == true) or (meKey ~= "" and mKey == meKey)
		if isOnline and not isSelf and not self:IsMemberInInstance(m) then
			local cz = (pf and pf.CanonicalZone and pf:CanonicalZone(m.zone)) or m.zone or ""
			if cz ~= "" and cz ~= "Azeroth" then
				openGuildByZone[cz] = (openGuildByZone[cz] or 0) + 1
			end
		end
	end

	-- Pass 2: Identify eligible open-world Mages (>=40) and Warlocks (>=20)
	local mages = {}
	local warlocks = {}
	local all = {}
	local skippedInstanced = 0
	local seen = {}

	for _, m in ipairs(roster) do
		local isOnline = (m.online == true or m.online == 1)
		local mKey = TrimLower(m.canonKey or m.name)
		local isSelf = (m.isSelf == true) or (meKey ~= "" and mKey == meKey)
		if isOnline and not isSelf and mKey ~= "" and not seen[mKey] then
			seen[mKey] = true
			local cls = self:NormalizeClass(m.class, m.classDisplay)
			if cls == "MAGE" or cls == "WARLOCK" then
				if self:IsMemberInInstance(m) then
					skippedInstanced = skippedInstanced + 1
				else
					local lvl = tonumber(m.level) or 0
					local rawX = tonumber(m.x) or 0
					local rawY = tonumber(m.y) or 0
					local hasLiveGPS = (rawX > 0 or rawY > 0)
					local pctX = hasLiveGPS and (rawX <= 1 and rawX * 100 or rawX) or nil
					local pctY = hasLiveGPS and (rawY <= 1 and rawY * 100 or rawY) or nil
					local nodeId, canonZone = self:ResolveMemberNode(m.zone, rawX, rawY, faction)

					if nodeId then
						local node = pf and pf.NODES and pf.NODES[nodeId]
						local finalX = pctX or (node and node.x) or 50
						local finalY = pctY or (node and node.y) or 50

						if cls == "MAGE" and lvl >= self.MAGE_MIN_LEVEL then
							local unlockedPortals = {}
							for _, p in ipairs(self.MAGE_PORTALS[faction] or {}) do
								if lvl >= p.minLevel then
									table.insert(unlockedPortals, p)
								end
							end
							if #unlockedPortals > 0 then
								local costSec = self:EstimateMagePortalCost(hasLiveGPS)
								local entry = {
									name = m.name or mKey,
									class = "MAGE",
									level = lvl,
									zone = canonZone,
									rawZone = m.zone or canonZone,
									nodeId = nodeId,
									x = finalX,
									y = finalY,
									hasLiveGPS = hasLiveGPS,
									portals = unlockedPortals,
									estimatedCostSec = costSec,
									helperPenaltySec = 0,
									nearbyHelpers = 0,
								}
								table.insert(mages, entry)
								table.insert(all, entry)
							end
						elseif cls == "WARLOCK" and lvl >= self.WARLOCK_MIN_LEVEL then
							local zoneTotal = openGuildByZone[canonZone] or 1
							local nearbyHelpers = math.max(0, zoneTotal - 1)
							local costSec, helperPen = self:EstimateWarlockSummonCost(nearbyHelpers, hasLiveGPS)
							local entry = {
								name = m.name or mKey,
								class = "WARLOCK",
								level = lvl,
								zone = canonZone,
								rawZone = m.zone or canonZone,
								nodeId = nodeId,
								x = finalX,
								y = finalY,
								hasLiveGPS = hasLiveGPS,
								nearbyHelpers = nearbyHelpers,
								helperPenaltySec = helperPen,
								estimatedCostSec = costSec,
							}
							table.insert(warlocks, entry)
							table.insert(all, entry)
						end
					end
				end
			end
		end
	end

	table.sort(mages, function(a, b)
		if a.estimatedCostSec ~= b.estimatedCostSec then return a.estimatedCostSec < b.estimatedCostSec end
		return (a.name or "") < (b.name or "")
	end)
	table.sort(warlocks, function(a, b)
		if a.estimatedCostSec ~= b.estimatedCostSec then return a.estimatedCostSec < b.estimatedCostSec end
		return (a.name or "") < (b.name or "")
	end)

	self.lastSummary = {
		mages = #mages,
		warlocks = #warlocks,
		skippedInstanced = skippedInstanced,
	}

	return {
		mages = mages,
		warlocks = warlocks,
		all = all,
		skippedInstanced = skippedInstanced,
	}
end

-- Builds dynamic directed edges for Dijkstra inside PluribusHivePathfinder:ComputeRoute.
-- - Mage Portal edge: mage.nodeId -> portalDestNodeId (player meets Mage, takes portal to capital city)
-- - Warlock Summon edge: startNodeId -> warlock.nodeId (Warlock summons player directly, with 2-helper penalty)
function PluribusHiveGuildTransit:BuildTransitEdges(startNodeId, faction, opts)
	opts = opts or {}
	local cfg = (_G.PluribusHive and _G.PluribusHive.GetConfig and _G.PluribusHive:GetConfig()) or {}
	local enabled = (opts.useGuildTransit ~= nil) and opts.useGuildTransit or (cfg.navUseGuildTransit ~= false)
	if not enabled or not startNodeId then
		return {}, { mages = 0, warlocks = 0, skippedInstanced = 0, enabled = false }
	end

	local providers = self:GetEligibleProviders({
		faction = faction,
		guildMembers = opts.guildMembers,
		selfName = opts.selfName,
	})

	local bestByKey = {}
	local edges = {}
	local isDE = (_G.PluribusL and _G.PluribusL.GetLanguage and _G.PluribusL:GetLanguage() == "deDE")

	-- 1. Guild Mage Portals: mage.nodeId -> capital city node
	for _, mage in ipairs(providers.mages) do
		for _, p in ipairs(mage.portals or {}) do
			if mage.nodeId ~= p.nodeId then
				local key = "P:" .. mage.nodeId .. "->" .. p.nodeId
				local prev = bestByKey[key]
				if not prev or mage.estimatedCostSec < prev.cost then
					bestByKey[key] = {
						from = mage.nodeId,
						to = p.nodeId,
						cost = mage.estimatedCostSec,
						meta = {
							mode = "portal",
							dist = 0,
							waitSec = mage.estimatedCostSec,
							isSynced = mage.hasLiveGPS,
							isRoad = false,
							providerName = mage.name,
							providerClass = "MAGE",
							providerLevel = mage.level,
							providerZone = mage.zone,
							spellLabel = isDE and p.spellDE or p.spell,
							helperPenaltySec = 0,
							nearbyHelpers = 0,
						},
					}
				end
			end
		end
	end

	-- 2. Guild Warlock Summons: startNodeId -> warlock.nodeId (penalized for 2-helper coordination!)
	for _, wl in ipairs(providers.warlocks) do
		if wl.nodeId ~= startNodeId then
			local key = "S:" .. startNodeId .. "->" .. wl.nodeId
			local prev = bestByKey[key]
			if not prev or wl.estimatedCostSec < prev.cost then
				bestByKey[key] = {
					from = startNodeId,
					to = wl.nodeId,
					cost = wl.estimatedCostSec,
					meta = {
						mode = "summon",
						dist = 0,
						waitSec = wl.estimatedCostSec,
						isSynced = wl.hasLiveGPS,
						isRoad = false,
						providerName = wl.name,
						providerClass = "WARLOCK",
						providerLevel = wl.level,
						providerZone = wl.zone,
						spellLabel = isDE and "Ritual der Beschwörung" or "Ritual of Summoning",
						helperPenaltySec = wl.helperPenaltySec or 0,
						nearbyHelpers = wl.nearbyHelpers or 0,
					},
				}
			end
		end
	end

	for _, e in pairs(bestByKey) do
		table.insert(edges, e)
	end

	return edges, {
		mages = #providers.mages,
		warlocks = #providers.warlocks,
		skippedInstanced = providers.skippedInstanced,
		enabled = true,
	}
end

-- Formats a polite, ready-to-send whisper request for a Mage Portal or Warlock Summon
function PluribusHiveGuildTransit:FormatWhisperRequest(providerName, mode, destLabel)
	local isDE = (_G.PluribusL and _G.PluribusL.GetLanguage and _G.PluribusL:GetLanguage() == "deDE")
	local dest = tostring(destLabel or "Azeroth")
	local m = tostring(mode or "portal"):lower()
	if m == "summon" then
		if isDE then
			return string.format("Hey %s, hättest du kurz Zeit für einen Summon nach %s (falls 2 Helfer da sind)?", tostring(providerName or ""), dest)
		end
		return string.format("Hey %s, any chance for a summon to %s if you have 2 helpers nearby?", tostring(providerName or ""), dest)
	end
	if isDE then
		return string.format("Hey %s, könntest du mir bitte kurz ein Portal nach %s stellen?", tostring(providerName or ""), dest)
	end
	return string.format("Hey %s, could you please open a portal to %s?", tostring(providerName or ""), dest)
end

-- Opens the WoW chat input prefilled with a polite whisper (taint-safe; player hits Enter to send)
function PluribusHiveGuildTransit:OpenWhisperPrompt(providerName, mode, destLabel)
	if not providerName or providerName == "" then return false end
	local msg = self:FormatWhisperRequest(providerName, mode, destLabel)
	if _G.ChatFrame_OpenChat then
		pcall(_G.ChatFrame_OpenChat, "/w " .. tostring(providerName) .. " " .. msg)
		return true
	elseif _G.ChatFrame_SendTell then
		pcall(_G.ChatFrame_SendTell, tostring(providerName))
		return true
	end
	return false
end

function PluribusHiveGuildTransit:Initialize()
	if self.initialized then return end
	self.initialized = true

	-- Keep cached summary fresh whenever the guild roster updates
	if _G.PluribusMessaging and _G.PluribusMessaging.Subscribe then
		_G.PluribusMessaging:Subscribe("HIVE_ROSTER_UPDATED", function()
			pcall(function() PluribusHiveGuildTransit:GetEligibleProviders() end)
		end)
	end
end

return PluribusHiveGuildTransit
