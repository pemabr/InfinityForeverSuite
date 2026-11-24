-- InfinityHive Smart Guild LFG Matcher
-- Monitors guild chat & structured Hive LFG posts; notifies you ONLY when your class, role, and level match

InfinityHiveLFG = {
	initialized = false,
	lastNotified = {},
}
_G.InfinityHiveLFG = InfinityHiveLFG

-- Classic / Warcraft Forever Dungeons & Raids with level brackets
InfinityHiveLFG.DUNGEONS = {
	{ keys = { "rfc", "ragefire" }, name = "Ragefire Chasm", min = 13, max = 18 },
	{ keys = { "wc", "wailing" }, name = "Wailing Caverns", min = 17, max = 24 },
	{ keys = { "dm", "vc", "deadmines" }, name = "The Deadmines", min = 17, max = 24 },
	{ keys = { "sfk", "shadowfang" }, name = "Shadowfang Keep", min = 22, max = 30 },
	{ keys = { "bfd", "blackfathom" }, name = "Blackfathom Deeps", min = 24, max = 32 },
	{ keys = { "stock", "stockade", "stockades" }, name = "The Stockade", min = 24, max = 32 },
	{ keys = { "gnomer", "gnomeregan" }, name = "Gnomeregan", min = 29, max = 38 },
	{ keys = { "rfk", "razorfen kraul" }, name = "Razorfen Kraul", min = 29, max = 38 },
	{ keys = { "sm", "scarlet", "gy", "lib", "armory", "cath" }, name = "Scarlet Monastery", min = 30, max = 45 },
	{ keys = { "rfd", "razorfen downs" }, name = "Razorfen Downs", min = 37, max = 46 },
	{ keys = { "ulda", "uldaman" }, name = "Uldaman", min = 41, max = 51 },
	{ keys = { "zf", "zulfarrak", "zul'farrak" }, name = "Zul'Farrak", min = 44, max = 54 },
	{ keys = { "mara", "maraudon" }, name = "Maraudon", min = 46, max = 55 },
	{ keys = { "st", "sunken temple", "atal'hakkar" }, name = "Sunken Temple", min = 50, max = 56 },
	{ keys = { "brd", "blackrock depths" }, name = "Blackrock Depths", min = 52, max = 60 },
	{ keys = { "lbrs", "lower blackrock" }, name = "Lower Blackrock Spire", min = 55, max = 60 },
	{ keys = { "ubrs", "upper blackrock" }, name = "Upper Blackrock Spire", min = 58, max = 60 },
	{ keys = { "scholo", "scholomance" }, name = "Scholomance", min = 58, max = 60 },
	{ keys = { "strat", "stratholme" }, name = "Stratholme", min = 58, max = 60 },
	{ keys = { "dme", "dmw", "dmn", "dire maul" }, name = "Dire Maul", min = 55, max = 60 },
	{ keys = { "zg", "zul'gurub", "zulgurub" }, name = "Zul'Gurub", min = 60, max = 60 },
	{ keys = { "aq20", "ruins" }, name = "Ruins of Ahn'Qiraj", min = 60, max = 60 },
	{ keys = { "mc", "molten core" }, name = "Molten Core", min = 60, max = 60 },
	{ keys = { "ony", "onyxia" }, name = "Onyxia's Lair", min = 60, max = 60 },
	{ keys = { "bwl", "blackwing" }, name = "Blackwing Lair", min = 60, max = 60 },
	{ keys = { "aq40", "temple" }, name = "Temple of Ahn'Qiraj", min = 60, max = 60 },
	{ keys = { "naxx", "naxxramas" }, name = "Naxxramas", min = 60, max = 60 },
}

local CLASS_KEYWORDS = {
	WARRIOR = { "warrior", "warri", "krieger", "warr" },
	PALADIN = { "paladin", "pala", "pally" },
	HUNTER  = { "hunter", "jäger", "hunt" },
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

local function ContainsWord(lowerMsg, word)
	return lowerMsg:find("%f[%a]" .. word .. "%f[%A]") ~= nil
end

function InfinityHiveLFG:ParseGuildChat(sender, msg)
	if not msg or msg == "" then return nil end
	local lower = msg:lower()

	-- Must look like an LFG/LFM message (English or German)
	local isLFG = lower:find("lf%d*m") or lower:find("%f[%a]lfg%f[%A]") or lower:find("%f[%a]lfm%f[%A]")
		or lower:find("suche") or lower:find("suchen") or lower:find("brauchen") or lower:find("need ")
		or lower:find("anyone for") or lower:find("wer lust auf")
	if not isLFG then return nil end

	local activity = "Guild Group"
	local minLvl, maxLvl = 1, 60
	for _, d in ipairs(self.DUNGEONS) do
		for _, k in ipairs(d.keys) do
			if k:find(" ") then
				if lower:find(k, 1, true) then
					activity, minLvl, maxLvl = d.name, d.min, d.max
					break
				end
			elseif ContainsWord(lower, k) then
				activity, minLvl, maxLvl = d.name, d.min, d.max
				break
			end
		end
		if activity ~= "Guild Group" then break end
	end

	-- Explicit level range override e.g. "35-42" or "lv 40"
	local lo, hi = lower:match("(%d%d?)%s*%-%s*(%d%d?)")
	if lo and hi then
		minLvl, maxLvl = tonumber(lo), tonumber(hi)
	end

	-- Detect wanted roles
	local wantedRoles = {}
	if lower:find("tank") then wantedRoles.TANK = true end
	if lower:find("heal") or lower:find("heiler") then wantedRoles.HEALER = true end
	if lower:find("dps") or lower:find("dd") or lower:find("damage") then wantedRoles.DPS = true end

	-- Detect specific wanted classes
	local wantedClasses = {}
	for cls, words in pairs(CLASS_KEYWORDS) do
		for _, w in ipairs(words) do
			if ContainsWord(lower, w) then
				wantedClasses[cls] = true
			end
		end
	end

	return {
		sender = sender,
		activity = activity,
		message = msg,
		minLevel = minLvl,
		maxLevel = maxLvl,
		roles = wantedRoles,
		classes = wantedClasses,
		postedAt = time(),
	}
end

function InfinityHiveLFG:DoesPlayerMatch(post)
	if not post then return false end
	local myLevel = UnitLevel and UnitLevel("player") or 60
	local myClass = InfinityHive:GetPlayerClass()
	local myPreferredRole = InfinityHive:GetPlayerRole()

	-- Level check (allow small +/- 2 level grace window)
	if myLevel < ((post.minLevel or 1) - 2) or myLevel > ((post.maxLevel or 60) + 5) then
		return false
	end

	-- If specific classes are requested, check class match
	local hasClassFilter = next(post.classes or {}) ~= nil
	if hasClassFilter then
		return post.classes[myClass] == true
	end

	-- If specific roles are requested, check role capability / preferred role
	local hasRoleFilter = next(post.roles or {}) ~= nil
	if hasRoleFilter then
		if post.roles[myPreferredRole] then return true end
		local cap = CLASS_ROLES[myClass] or {}
		for r in pairs(post.roles) do
			if cap[r] then return true end
		end
		return false
	end

	-- Open group for our level range!
	return true
end

function InfinityHiveLFG:RegisterPost(post)
	if not post or not post.sender then return end
	local db = InfinityHive:GetDB()
	db.lfgPosts[post.sender] = post

	local me = InfinityHive:GetPlayerShortName()
	if post.sender == me then return end
	if not InfinityHive:GetConfig().showLFGMatches then return end

	if self:DoesPlayerMatch(post) then
		local now = GetTime()
		if self.lastNotified[post.sender] and (now - self.lastNotified[post.sender]) < 90 then
			return
		end
		self.lastNotified[post.sender] = now

		InfinityHive:AddFeedEvent("LFG", string.format("%s is looking for your class/level: %s", post.sender, post.activity))

		if _G.InfinityHiveUI and _G.InfinityHiveUI.ShowToast then
			_G.InfinityHiveUI:ShowToast({
				kind = "LFG",
				title = string.format("Guild LFG Match: %s", post.activity),
				body = string.format("%s: \"%s\" (Lv %d-%d)", post.sender, post.message:sub(1, 70), post.minLevel or 1, post.maxLevel or 60),
				color = { 0.22, 0.74, 0.97 },
				duration = 12,
				action1 = {
					label = "Whisper 'Inv!'",
					onClick = function()
						if SendChatMessage then
							pcall(SendChatMessage, "Hey! I'm a " .. InfinityHive:GetPlayerClass() .. " (" .. InfinityHive:GetPlayerRole() .. ") — invite for " .. post.activity .. "?", "WHISPER", nil, post.sender)
						end
					end,
				},
			})
		end
	end
end

function InfinityHiveLFG:PostLFG(activity, roleNeeded, minLvl, maxLvl, note)
	local me = InfinityHive:GetPlayerShortName()
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

	if InfinityHive:GetConfig().shareLFG then
		local payload = string.format("%s|%s|%d|%d|%s", activity:gsub("|", " "), roleNeeded, minLvl, maxLvl, msg:gsub("|", " "))
		InfinityHive:Send("LFG", payload, "GUILD")
	end
end

function InfinityHiveLFG:GetActivePosts()
	local db = InfinityHive:GetDB()
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

function InfinityHiveLFG:Initialize()
	if self.initialized then return end
	self.initialized = true

	InfinityHive:RegisterHandler("LFG", function(sender, body)
		local activity, roleNeeded, minStr, maxStr, msg = body:match("^([^|]*)|([^|]*)|(%d+)|(%d+)|(.*)$")
		if not activity then return end
		local roles = {}
		if roleNeeded == "TANK" or roleNeeded == "HEALER" or roleNeeded == "DPS" then
			roles[roleNeeded] = true
		end
		InfinityHiveLFG:RegisterPost({
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
			local short = tostring(sender or ""):gsub("%-.+$", "")
			local post = InfinityHiveLFG:ParseGuildChat(short, msg)
			if post then
				InfinityHiveLFG:RegisterPost(post)
			end
		end
	end)
end

return InfinityHiveLFG
