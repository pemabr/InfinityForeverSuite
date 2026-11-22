local Bridge = {}
_G.InfinityEncounterDBMBridge = Bridge

local function Public(value)
	if _G.issecretvalue and _G.issecretvalue(value) then return nil end
	return value
end

local function ValidNumber(value, allowZero)
	value = Public(value)
	return type(value) == "number" and value == value and value >= (allowZero and 0 or 0.001)
		and value <= 86400
end

local function TimerID(value)
	value = Public(value)
	if type(value) ~= "string" or value == "" or #value > 150 or value:find("[%z\1-\31]") then return nil end
	return "dbm:" .. value
end

function Bridge:Initialize(db)
	if self.initialized then return end
	db = Public(db)
	if type(db) ~= "table" or (_G.issecretvalue and (issecretvalue(db.dbmEnabled) or issecretvalue(db.dbmImportAllowed)))
		or (db.dbmEnabled ~= nil and type(db.dbmEnabled) ~= "boolean")
		or (db.dbmImportAllowed ~= nil and type(db.dbmImportAllowed) ~= "boolean") then
		InfinityUtils:Warning("Invalid DBM integration settings.", "Encounter")
		return
	end
	self.db, self.initialized = db, true
	if _G.StaticPopupDialogs and _G.StaticPopup_Show then
		StaticPopupDialogs.INFINITY_ENCOUNTER_DBM = {
			text = "DBM found. Show its public live timers in Infinity Encounter?",
			button1 = "Allow", button2 = "No",
			OnAccept = function() Bridge:SetEnabled(true) end,
			OnCancel = function() Bridge:SetEnabled(false) end,
			timeout = 0, whileDead = true, hideOnEscape = false,
		}
		StaticPopupDialogs.INFINITY_ENCOUNTER_DBM_IMPORT = {
			text = "DBM found. Allow creating optional boss-watch presets from spell IDs in its loaded modules?",
			button1 = "Allow", button2 = "No",
			OnAccept = function() Bridge:SetImportAllowed(true) end,
			OnCancel = function() Bridge:SetImportAllowed(false) end,
			timeout = 0, whileDead = true, hideOnEscape = false,
		}
	end
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("ADDON_LOADED")
	frame:RegisterEvent("PLAYER_LOGIN")
	frame:RegisterEvent("PLAYER_REGEN_ENABLED")
	frame:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGIN" then self.loggedIn = true end
		if self.loggedIn then self:Detect() end
	end)
	self.frame = frame
	if _G.IsLoggedIn and Public(IsLoggedIn()) then self.loggedIn = true; self:Detect() end
end

function Bridge:Available()
	local dbm = Public(_G.DBM)
	return type(dbm) == "table" and type(Public(dbm.RegisterCallback)) == "function"
		and type(Public(dbm.UnregisterCallback)) == "function"
end

function Bridge:Detect()
	local timersAvailable, importsAvailable = self:Available(), self:ImportAvailable()
	if not timersAvailable and not importsAvailable then return end
	if timersAvailable and self.db.dbmEnabled then self:Attach() end
	local combat = _G.InCombatLockdown and InCombatLockdown()
	if _G.issecretvalue and issecretvalue(combat) then return end
	if combat then return end
	if timersAvailable and self.db.dbmEnabled == nil and not self.offered then
		self.offered = true
		if _G.StaticPopupDialogs and _G.StaticPopup_Show then
			if not StaticPopup_Show("INFINITY_ENCOUNTER_DBM") then self.offered = false end
		else
			print("DBM found. Enable its live timers with /encounter dbm on.")
		end
	end
	if importsAvailable and self.db.dbmImportAllowed == nil and not self.importOffered then
		self.importOffered = true
		if _G.StaticPopupDialogs and _G.StaticPopup_Show then
			if not StaticPopup_Show("INFINITY_ENCOUNTER_DBM_IMPORT") then self.importOffered = false end
		else
			print("DBM modules found. Allow optional spell-ID imports with /encounter dbm import on.")
		end
	end
end

function Bridge:ImportAvailable()
	local dbm = Public(_G.DBM)
	return type(dbm) == "table" and type(Public(dbm.GetModByName)) == "function"
		and type(Public(dbm.Mods)) == "table"
end

function Bridge:SetImportAllowed(allowed)
	if not self.initialized then return false end
	self.db.dbmImportAllowed = not not allowed
	print(allowed and "DBM spell-ID imports enabled." or "DBM spell-ID imports disabled.")
	return true
end

function Bridge:GetModules(filter)
	if not self:ImportAvailable() then InfinityUtils:Warning("DBM modules are unavailable.", "Encounter"); return end
	filter = Public(filter)
	if type(filter) ~= "string" or #filter > 75 then
		InfinityUtils:Warning("Invalid DBM module filter.", "Encounter")
		return
	end
	filter = filter:lower()
	local ids = {}
	for _, module in ipairs(DBM.Mods) do
		module = Public(module)
		local id = type(module) == "table" and Public(module.id)
		if type(id) == "string" and id:match("^[%w_%.%-]+$") and #id <= 75
			and id:lower():find(filter, 1, true) then ids[#ids + 1] = id end
	end
	table.sort(ids)
	return ids
end

function Bridge:ListModules(filter)
	local ids = self:GetModules(filter)
	if not ids then return end
	print("Loaded DBM module IDs:")
	for index = 1, math.min(#ids, 100) do print(ids[index]) end
	if #ids > 100 then print("Only the first 100 modules are shown; use a filter.") end
	if #ids == 0 then print("No matching DBM boss modules are loaded.") end
end

function Bridge:ImportModule(id)
	id = Public(id)
	if not self.db or not self.db.dbmImportAllowed then
		InfinityUtils:Warning("Allow DBM imports first: /encounter dbm import on.", "Encounter")
		return false
	end
	if not self:ImportAvailable() or type(id) ~= "string" or #id > 75 or not id:match("^[%w_%.%-]+$") then
		InfinityUtils:Warning("Invalid or unavailable DBM module.", "Encounter")
		return false
	end
	local ok, module = pcall(DBM.GetModByName, DBM, id)
	module = Public(module)
	if not ok then
		InfinityUtils:Warning("DBM module lookup failed: " .. tostring(module or "protected error"), "Encounter")
		return false
	end
	if type(module) ~= "table" then
		InfinityUtils:Warning("DBM module is not loaded: " .. id, "Encounter")
		return false
	end
	local ids, seen, scanned, skipped = {}, {}, 0, 0
	for _, field in ipairs({ "timers", "announces", "specwarns" }) do
		local entries = Public(module[field])
		if type(entries) ~= "table" then
			skipped = skipped + 1
		else
			for _, entry in ipairs(entries) do
				scanned = scanned + 1
				if scanned > 5000 then InfinityUtils:Warning("DBM module is too large to import safely.", "Encounter"); return false end
				entry = Public(entry)
				local spellID = type(entry) == "table" and Public(entry.spellId)
				if type(spellID) == "number" and spellID > 0 and spellID <= 1000000000
					and spellID == math.floor(spellID) then
					if not seen[spellID] then ids[#ids + 1] = spellID; seen[spellID] = true end
				else skipped = skipped + 1 end
			end
		end
	end
	if #ids == 0 or #ids > 200 then
		InfinityUtils:Warning("DBM module has no usable spell IDs or exceeds the 200-spell preset limit.", "Encounter")
		return false
	end
	table.sort(ids)
	local steps = {}
	for index, spellID in ipairs(ids) do steps[index] = { questID = spellID, description = "Spell " .. spellID } end
	if not _G.InfinityEncounterPresets or not InfinityEncounterPresets:Save("DBM " .. id, steps) then return false end
	print("Imported " .. #ids .. " spell IDs from DBM; skipped " .. skipped .. " unavailable entries. Activate the preset if wanted.")
	return true
end

function Bridge:Detach()
	self.attached = false
	if self.provider then
		for event, callback in pairs(self.callbacks) do
			local ok, err = pcall(self.provider.UnregisterCallback, self.provider, event, callback)
			if not ok then
				InfinityUtils:Warning("DBM callback removal failed: " .. tostring(Public(err) or "protected error"), "Encounter")
				return false
			end
			self.callbacks[event] = nil
		end
		self.provider = nil
	end
	local remove = {}
	for id in pairs(InfinityEncounterTimer.timers) do
		if type(id) == "string" and id:match("^dbm:") then remove[#remove + 1] = id end
	end
	for _, id in ipairs(remove) do InfinityEncounterTimer:RemoveTimer(id) end
	return true
end

function Bridge:Attach()
	if not self:Available() then
		InfinityUtils:Warning("DBM live timers are unavailable.", "Encounter")
		return false
	end
	if self.provider == DBM and self.attached then return true end
	if self.provider and not self:Detach() then return false end
	self.callbacks = {}
	self.provider = DBM
	for _, event in ipairs({ "DBM_TimerBegin", "DBM_TimerStart", "DBM_TimerStop",
		"DBM_TimerUpdate", "DBM_TimerPause", "DBM_TimerResume", "DBM_TimerUpdateName" }) do
		local callback = function(...) self:OnTimer(...) end
		local ok, err = pcall(DBM.RegisterCallback, DBM, event, callback)
		if not ok then
			InfinityUtils:Warning("DBM callback registration failed: " .. tostring(Public(err) or "protected error"), "Encounter")
			self:Detach()
			return false
		end
		self.callbacks[event] = callback
	end
	self.attached = true
	return true
end

function Bridge:SetEnabled(enabled)
	if not self.initialized then return false end
	if enabled and not self:Attach() then return false end
	if not enabled and not self:Detach() then return false end
	self.db.dbmEnabled = not not enabled
	print(enabled and "DBM live timers enabled." or "DBM live timers disabled.")
	return true
end

function Bridge:OnTimer(event, id, first, second, ...)
	event, id, first, second = Public(event), TimerID(id), Public(first), Public(second)
	if not id then return end
	local timers = InfinityEncounterTimer
	if event == "DBM_TimerBegin" or event == "DBM_TimerStart" then
		if event == "DBM_TimerBegin" and select("#", ...) >= 15 then
			local enabled, textOnly = select(15, ...)
			if (_G.issecretvalue and (issecretvalue(enabled) or issecretvalue(textOnly)))
				or (enabled ~= true and textOnly ~= true) then
				timers:RemoveTimer(id)
				return
			end
		end
		if type(first) ~= "string" or first == "" or #first > 200 or not ValidNumber(second) then return end
		timers:CreateTimer(id, "[DBM] " .. first, second)
	elseif event == "DBM_TimerStop" then
		timers:RemoveTimer(id)
	else
		local timer = timers:GetTimer(id)
		if not timer then return end
		if event == "DBM_TimerPause" and timer.pausedRemaining == nil then
			timer.pausedRemaining = timer:GetRemaining()
		elseif event == "DBM_TimerResume" and timer.pausedRemaining ~= nil then
			timer.duration, timer.start_time, timer.pausedRemaining = timer.pausedRemaining, GetTime(), nil
		elseif event == "DBM_TimerUpdate" and ValidNumber(first, true) and ValidNumber(second, true) then
			local remaining = second - first
			if remaining <= 0 then timers:RemoveTimer(id)
			elseif timer.pausedRemaining ~= nil then timer.pausedRemaining = remaining
			else timer.duration, timer.start_time = remaining, GetTime() end
		elseif event == "DBM_TimerUpdateName" and type(first) == "string" and first ~= "" and #first <= 200 then
			timer.name = "[DBM] " .. first
		end
	end
end

return Bridge
