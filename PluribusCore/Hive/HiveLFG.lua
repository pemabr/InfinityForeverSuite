-- PluribusHive Smart Guild LFG Matcher
-- Monitors guild chat & structured Hive LFG posts; notifies you ONLY when your class, role, and level match.
-- Strict anti-false-positive filtering: never misinterprets casual conversations about questgivers,
-- NPC locations, crafting requests, or trade chatter as LFG!

PluribusHiveLFG = {
	initialized = false,
	lastNotified = {},
}
_G.PluribusHiveLFG = PluribusHiveLFG

-- Classic / Warcraft Forever Dungeons & Raids with EN + DE keywords & level brackets
PluribusHiveLFG.DUNGEONS = {
	{ keys = { "rfc", "ragefire", "flammenschlund" }, name = "Ragefire Chasm", min = 13, max = 18 },
	{ keys = { "wc", "wailing", "hdw", "höhlen des wehklagens", "hoehlen des wehklagens" }, name = "Wailing Caverns", min = 17, max = 24 },
	{ keys = { "dm", "vc", "deadmines", "todesminen" }, name = "The Deadmines", min = 17, max = 24 },
	{ keys = { "sfk", "shadowfang", "bsf", "burg schattenfang", "schattenfang" }, name = "Shadowfang Keep", min = 22, max = 30 },
	{ keys = { "bfd", "blackfathom", "bft", "tiefschwarze grotte" }, name = "Blackfathom Deeps", min = 24, max = 32 },
	{ keys = { "stock", "stockade", "stockades", "verlies" }, name = "The Stockade", min = 24, max = 32 },
	{ keys = { "gnomer", "gnomeregan" }, name = "Gnomeregan", min = 29, max = 38 },
	{ keys = { "rfk", "razorfen kraul", "kral der klingenhauer", "kral" }, name = "Razorfen Kraul", min = 29, max = 38 },
	{ keys = { "sm", "scarlet", "gy", "lib", "armory", "cath", "kloster", "scharlachrote", "kathedrale", "waffenkammer", "bibliothek", "friedhof" }, name = "Scarlet Monastery", min = 30, max = 45 },
	{ keys = { "rfd", "razorfen downs", "hügel der klingenhauer", "huegel der klingenhauer" }, name = "Razorfen Downs", min = 37, max = 46 },
	{ keys = { "ulda", "uldaman" }, name = "Uldaman", min = 41, max = 51 },
	{ keys = { "zf", "zulfarrak", "zul'farrak" }, name = "Zul'Farrak", min = 44, max = 54 },
	{ keys = { "mara", "maraudon" }, name = "Maraudon", min = 46, max = 55 },
	{ keys = { "st", "sunken temple", "atal'hakkar", "versunkener tempel" }, name = "Sunken Temple", min = 50, max = 56 },
	{ keys = { "brd", "blackrock depths", "brt", "schwarzfelstiefen" }, name = "Blackrock Depths", min = 52, max = 60 },
	{ keys = { "lbrs", "lower blackrock", "untere schwarzfelsspitze" }, name = "Lower Blackrock Spire", min = 55, max = 60 },
	{ keys = { "ubrs", "upper blackrock", "obere schwarzfelsspitze" }, name = "Upper Blackrock Spire", min = 58, max = 60 },
	{ keys = { "scholo", "scholomance" }, name = "Scholomance", min = 58, max = 60 },
	{ keys = { "strat", "stratholme" }, name = "Stratholme", min = 58, max = 60 },
	{ keys = { "dme", "dmw", "dmn", "dire maul", "db", "düsterbruch", "duesterbruch" }, name = "Dire Maul", min = 55, max = 60 },
	{ keys = { "zg", "zul'gurub", "zulgurub" }, name = "Zul'Gurub", min = 60, max = 60 },
	{ keys = { "aq20", "ruinen von ahn'qiraj" }, name = "Ruins of Ahn'Qiraj", min = 60, max = 60 },
	{ keys = { "mc", "molten core", "geschmolzener kern" }, name = "Molten Core", min = 60, max = 60 },
	{ keys = { "ony", "onyxia" }, name = "Onyxia's Lair", min = 60, max = 60 },
	{ keys = { "bwl", "blackwing", "pechschwingenhort" }, name = "Blackwing Lair", min = 60, max = 60 },
	{ keys = { "aq40", "tempel von ahn'qiraj" }, name = "Temple of Ahn'Qiraj", min = 60, max = 60 },
	{ keys = { "naxx", "naxxramas" }, name = "Naxxramas", min = 60, max = 60 },
}

local CLASS_KEYWORDS = {
	WARRIOR = { "warrior", "warri", "krieger", "warr" },
	PALADIN = { "paladin", "pala", "pally" },
	HUNTER  = { "hunter", "jäger", "jaeger", "hunt" },
	ROGUE   = { "rogue", "schurke" },
	PRIEST  = { "priest", "priester" },
	SHAMAN  = { "shaman", "schamane", "shammy" },
	MAGE    = { "mage", "magier" },
	WARLOCK = { "warlock", "hexer", "lock" },
	DRUID   = { "druid", "druide", "dudu" },
}

local CLASS_ROLES = {
	WARRIOR = { TANK = true, DPS = true },
	PALADIN = { TANK = true, HEALER = true, DPS = true },
	DRUID   = { TANK = true, HEALER = true, DPS = true },
	PRIEST  = { HEALER = true, DPS = true },
	SHAMAN  = { HEALER = true, DPS = true },
	MAGE    = { DPS = true },
	WARLOCK = { DPS = true },
	ROGUE   = { DPS = true },
	HUNTER  = { DPS = true },
}

-- Patterns that clearly indicate a location/NPC/questgiver/trade/crafting conversation (NOT LFG!)
local NON_LFG_CHAT_PATTERNS = {
	"questgeber", "quest giver", "questgiver", "quest%-geber",
	"wo ist", "wo sind", "wo steht", "wo find", "wo gibt", "wo liegt", "wo bekomm", "wo kann ich", "wo war",
	"weiß jemand wo", "weiss jemand wo", "weis jemand wo",
	"where is", "where are", "where do i find", "where can i find", "where does", "anyone know where",
	"lehrer", "trainer", "händler", "haendler", "vendor", "flugmeister", "flight master", "briefkasten", "mailbox",
	"npc", "abgeben", "turn in", "abzugeben",
	"wtb", "wts", "verkaufe", "kaufe", "suche verzauberer", "suche schmied", "suche alchi", "suche schneider",
	"suche ingi", "suche lederer", "suche tasche", "suche portal", "kann jemand herstellen", "kann mir jemand craften",
}

local GROUP_CONTEXT_WORDS = {
	"gruppe", "grp", "group", "ini", "instanz", "instance", "dungeon", "raid", "boss",
	"elite", "elitequest", "elite-quest", "gruppenquest", "group quest",
	"mitkommen", "mitgehen", "mitspieler", "leute für", "leute fuer", "noch platz", "run",
}

local function ContainsWord(lowerMsg, word)
	if word:find(" ", 1, true) or word:find("-", 1, true) then
		return lowerMsg:find(word, 1, true) ~= nil
	end
	return lowerMsg:find("%f[%a]" .. word .. "%f[%A]") ~= nil
end

function PluribusHiveLFG:ParseGuildChat(sender, msg)
	if not msg or msg == "" then return nil end
	local lower = msg:lower()

	-- 1. Strong explicit LFG / LFM tags (e.g. "LFM BRD", "LF2M Tank SM", "LFG Deadmines")
	local hasExplicitLFG = (lower:find("%f[%a]lf%d*m%f[%A]") ~= nil)
		or (lower:find("%f[%a]lfg%f[%A]") ~= nil)
		or (lower:find("%f[%a]lftank%f[%A]") ~= nil)
		or (lower:find("%f[%a]lfheal%f[%A]") ~= nil)
		or (lower:find("%f[%a]lfdps%f[%A]") ~= nil)

	-- 2. Reject casual conversations asking where a questgiver/NPC/vendor is or trade/crafting requests
	--    unless the message explicitly uses an LFG/LFM tag!
	if not hasExplicitLFG then
		for _, pat in ipairs(NON_LFG_CHAT_PATTERNS) do
			if lower:find(pat, 1, true) then
				return nil
			end
		end
	end

	-- 3. Soft German / English group-seeking triggers
	local hasSoftTrigger = hasExplicitLFG
		or ContainsWord(lower, "suche") or ContainsWord(lower, "suchen")
		or ContainsWord(lower, "brauchen") or ContainsWord(lower, "brauche")
		or lower:find("anyone for", 1, true) ~= nil
		or lower:find("wer lust auf", 1, true) ~= nil
		or lower:find("wer will mit", 1, true) ~= nil
		or lower:find("noch jemand", 1, true) ~= nil
		or lower:find("need ", 1, true) ~= nil
		or lower:find("looking for", 1, true) ~= nil

	if not hasSoftTrigger then return nil end

	-- 4. Detect Dungeon / Raid
	local activity = "Guild Group"
	local matchedDungeon = false
	local minLvl, maxLvl = 1, 60
	for _, d in ipairs(self.DUNGEONS) do
		for _, k in ipairs(d.keys) do
			if ContainsWord(lower, k) then
				activity, minLvl, maxLvl = d.name, d.min, d.max
				matchedDungeon = true
				break
			end
		end
		if matchedDungeon then break end
	end

	-- 5. Detect wanted roles
	local wantedRoles = {}
	if ContainsWord(lower, "tank") then wantedRoles.TANK = true end
	if ContainsWord(lower, "heal") or ContainsWord(lower, "heiler") or ContainsWord(lower, "healer") then wantedRoles.HEALER = true end
	if ContainsWord(lower, "dps") or ContainsWord(lower, "dd") or ContainsWord(lower, "dds") or ContainsWord(lower, "damage") then wantedRoles.DPS = true end
	local hasRole = next(wantedRoles) ~= nil

	-- 6. Detect explicit group context words (e.g. "gruppe", "instanz", "dungeon", "raid", "elitequest")
	local hasGroupContext = false
	for _, gw in ipairs(GROUP_CONTEXT_WORDS) do
		if ContainsWord(lower, gw) then
			hasGroupContext = true
			break
		end
	end

	-- 7. CRITICAL ANTI-FALSE-POSITIVE RULE:
	-- Soft words like "suche", "brauche", "need", "looking for" MUST be paired with
	-- a known dungeon/raid, a role (tank/heal/dps), OR an explicit group keyword ("gruppe"/"instanz"/"elitequest")!
	-- Plain sentences like "Ich suche den Questgeber" or "Suche noch Kräuter" are cleanly ignored!
	if not hasExplicitLFG and not matchedDungeon and not hasRole and not hasGroupContext then
		return nil
	end

	-- Explicit level range override e.g. "35-42"
	local lo, hi = lower:match("(%d%d?)%s*%-%s*(%d%d?)")
	if lo and hi then
		minLvl, maxLvl = tonumber(lo), tonumber(hi)
	end

	-- Detect specific wanted classes
	local wantedClasses = {}
	for cls, words in pairs(CLASS_KEYWORDS) do
		for _, w in ipairs(words) do
			if ContainsWord(lower, w) then
				wantedClasses[cls] = true
			end
		end
	end

	local normSender = (_G.PluribusHive and _G.PluribusHive.NormalizeName) and _G.PluribusHive:NormalizeName(sender) or tostring(sender or "")
	return {
		sender = normSender,
		activity = activity,
		message = msg,
		minLevel = minLvl,
		maxLevel = maxLvl,
		roles = wantedRoles,
		classes = wantedClasses,
		postedAt = time(),
	}
end

function PluribusHiveLFG:DoesPlayerMatch(post)
	if not post then return false end
	local myLevel = UnitLevel and UnitLevel("player") or 60
	local myClass = PluribusHive:GetPlayerClass()
	local myPreferredRole = PluribusHive:GetPlayerRole()

	if myLevel < ((post.minLevel or 1) - 2) or myLevel > ((post.maxLevel or 60) + 5) then
		return false
	end

	local hasClassFilter = next(post.classes or {}) ~= nil
	if hasClassFilter then
		return post.classes[myClass] == true
	end

	local hasRoleFilter = next(post.roles or {}) ~= nil
	if hasRoleFilter then
		if post.roles[myPreferredRole] then return true end
		local cap = CLASS_ROLES[myClass] or {}
		for r in pairs(post.roles) do
			if cap[r] then return true end
		end
		return false
	end

	return true
end

function PluribusHiveLFG:RegisterPost(post)
	if not post or not post.sender then return end
	local normSender = PluribusHive:NormalizeName(post.sender)
	post.sender = normSender
	local db = PluribusHive:GetDB()
	db.lfgPosts[normSender] = post

	local me = PluribusHive:GetPlayerShortName()
	if PluribusHive:SamePlayer(normSender, me) then return end
	if not PluribusHive:GetConfig().showLFGMatches then return end

	if self:DoesPlayerMatch(post) then
		local now = GetTime()
		if self.lastNotified[normSender] and (now - self.lastNotified[normSender]) < 90 then
			return
		end
		self.lastNotified[normSender] = now

		PluribusHive:AddFeedEvent("LFG", string.format("%s is looking for your class/level: %s", normSender, post.activity))

		if _G.PluribusHiveUI and _G.PluribusHiveUI.ShowToast then
			_G.PluribusHiveUI:ShowToast({
				kind = "LFG",
				title = string.format("Guild LFG Match: %s", post.activity),
				body = string.format("%s: \"%s\" (Lv %d-%d)", normSender, post.message:sub(1, 70), post.minLevel or 1, post.maxLevel or 60),
				color = { 0.22, 0.74, 0.97 },
				duration = 12,
				action1 = {
					label = "Whisper 'Inv!'",
					onClick = function()
						if SendChatMessage then
							pcall(SendChatMessage, "Hey! I'm a " .. PluribusHive:GetPlayerClass() .. " (" .. PluribusHive:GetPlayerRole() .. ") — invite for " .. post.activity .. "?", "WHISPER", nil, normSender)
						end
					end,
				},
			})
		end
	end
end

function PluribusHiveLFG:PostLFG(activity, roleNeeded, minLvl, maxLvl, note)
	local me = PluribusHive:GetPlayerShortName()
	local myLvl = UnitLevel and UnitLevel("player") or 60
	activity = (activity and activity ~= "") and activity or "Dungeon / Quest Group"
	minLvl = tonumber(minLvl) or math.max(1, myLvl - 3)
	maxLvl = tonumber(maxLvl) or math.min(60, myLvl + 3)
	roleNeeded = (roleNeeded and roleNeeded ~= "") and roleNeeded:upper() or "ANY"

	local roles = {}
	if roleNeeded == "TANK" or roleNeeded == "HEALER" or roleNeeded == "DPS" then
		roles[roleNeeded] = true
	end

	local msg = (note and note ~= "") and note or string.format("LFM %s (%s, Lv %d-%d)", activity, roleNeeded, minLvl, maxLvl)
	self:RegisterPost({
		sender = me,
		activity = activity,
		message = msg,
		minLevel = minLvl,
		maxLevel = maxLvl,
		roles = roles,
		classes = {},
		postedAt = time(),
	})

	if PluribusHive:GetConfig().shareLFG then
		local payload = string.format("%s|%s|%d|%d|%s", activity:gsub("|", " "), roleNeeded, minLvl, maxLvl, msg:gsub("|", " "))
		PluribusHive:Send("LFG", payload, "GUILD")
	end
end

function PluribusHiveLFG:GetActivePosts()
	local db = PluribusHive:GetDB()
	local now = time()
	local list = {}
	for sender, post in pairs(db.lfgPosts or {}) do
		if (now - (post.postedAt or 0)) <= 1200 then
			table.insert(list, post)
		else
			db.lfgPosts[sender] = nil
		end
	end
	table.sort(list, function(a, b) return (a.postedAt or 0) > (b.postedAt or 0) end)
	return list
end

function PluribusHiveLFG:Initialize()
	if self.initialized then return end
	self.initialized = true

	PluribusHive:RegisterHandler("LFG", function(sender, body)
		local activity, roleNeeded, minStr, maxStr, msg = body:match("^([^|]*)|([^|]*)|(%d+)|(%d+)|(.*)$")
		if not activity then return end
		local roles = {}
		if roleNeeded == "TANK" or roleNeeded == "HEALER" or roleNeeded == "DPS" then
			roles[roleNeeded] = true
		end
		PluribusHiveLFG:RegisterPost({
			sender = sender,
			activity = activity,
			message = msg or activity,
			minLevel = tonumber(minStr) or 1,
			maxLevel = tonumber(maxStr) or 60,
			roles = roles,
			classes = {},
			postedAt = time(),
		})
	end)

	local f = CreateFrame("Frame")
	pcall(f.RegisterEvent, f, "CHAT_MSG_GUILD")
	f:SetScript("OnEvent", function(_, event, msg, sender)
		if event == "CHAT_MSG_GUILD" then
			local short = PluribusHive:NormalizeName(sender)
			local post = PluribusHiveLFG:ParseGuildChat(short, msg)
			if post then
				PluribusHiveLFG:RegisterPost(post)
			end
		end
	end)
end

return PluribusHiveLFG
