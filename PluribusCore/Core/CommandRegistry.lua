-- PluribusCore Command Registry
-- Centralized slash command (with subcommand routing) and keybind management for WoW Forever

PluribusCommandRegistry = {
	commands = {},
	subcommands = {},
	descriptions = {},
	keybinds = {},
	commandAliases = {},
}

local function sanitizeSlashKey(cmd)
	return string.upper((cmd or "CMD"):gsub("[^%w]", "_"))
end

local function ensureSlashHook(rootCmd)
	local key = "PLURIBUS_" .. sanitizeSlashKey(rootCmd)
	if not SlashCmdList[key] then
		_G["SLASH_" .. key .. "1"] = "/" .. rootCmd
		SlashCmdList[key] = function(msg)
			msg = msg or ""
			local trimmed = msg:match("^%s*(.-)%s*$") or ""
			local sub, rest = trimmed:match("^(%S+)%s*(.*)$")
			local subKey = sub and string.lower(sub) or ""

			local subs = PluribusCommandRegistry.subcommands[rootCmd]
			if subKey ~= "" and subs and subs[subKey] then
				local ok, err = pcall(subs[subKey], rest, trimmed)
				if not ok and PluribusUtils and PluribusUtils.Error then
					PluribusUtils:Error("Command /" .. rootCmd .. " " .. subKey .. " error: " .. tostring(err), "CommandRegistry")
				end
				return
			end

			local handler = PluribusCommandRegistry.commands[rootCmd]
			if type(handler) == "function" then
				local args = (PluribusUtils and PluribusUtils.Split) and PluribusUtils:Split(trimmed, " ") or {}
				local ok, err = pcall(handler, args, trimmed)
				if not ok and PluribusUtils and PluribusUtils.Error then
					PluribusUtils:Error("Command /" .. rootCmd .. " error: " .. tostring(err), "CommandRegistry")
				end
			end
		end
	end
end

-- Register a slash command (supports 3 signatures:
-- 1) RegisterCommand("pluribus", callback, aliases)
-- 2) RegisterCommand({ name = "guild", aliases = {"g"}, description = "...", func = cb })
-- 3) RegisterCommand("/details breakdown", "Description", callback)
function PluribusCommandRegistry:RegisterCommand(command, callbackOrDesc, aliasesOrCallback)
	local cmdStr, callback, aliases, description

	if type(command) == "table" then
		cmdStr = command.name or command.command
		callback = command.func or command.callback or command.action
		aliases = command.aliases
		description = command.description
	elseif type(callbackOrDesc) == "string" and type(aliasesOrCallback) == "function" then
		cmdStr = command
		description = callbackOrDesc
		callback = aliasesOrCallback
	else
		cmdStr = command
		callback = callbackOrDesc
		aliases = aliasesOrCallback
	end

	if not cmdStr or type(callback) ~= "function" then
		return false
	end

	cmdStr = string.lower((cmdStr:gsub("^/", "")):match("^%s*(.-)%s*$") or "")
	if cmdStr == "" then return false end

	local rootCmd, subCmd = cmdStr:match("^(%S+)%s+(%S+)$")
	if rootCmd and subCmd then
		self.subcommands[rootCmd] = self.subcommands[rootCmd] or {}
		self.subcommands[rootCmd][subCmd] = callback
		self.descriptions[rootCmd .. " " .. subCmd] = description or ""
		ensureSlashHook(rootCmd)
	else
		self.commands[cmdStr] = callback
		self.descriptions[cmdStr] = description or ""
		ensureSlashHook(cmdStr)

		if aliases and type(aliases) == "table" then
			local key = "PLURIBUS_" .. sanitizeSlashKey(cmdStr)
			local idx = 2
			for _, alias in ipairs(aliases) do
				alias = string.lower((tostring(alias):gsub("^/", "")))
				if alias ~= "" and alias ~= cmdStr then
					self.commandAliases[alias] = cmdStr
					_G["SLASH_" .. key .. tostring(idx)] = "/" .. alias
					idx = idx + 1
				end
			end
		end
	end

	return true
end

function PluribusCommandRegistry:GetCommand(command)
	if not command then return nil end
	command = string.lower((command:gsub("^/", "")))
	if self.commandAliases[command] then
		command = self.commandAliases[command]
	end
	return self.commands[command]
end

-- Register a keybind (supports positional args OR table config)
function PluribusCommandRegistry:RegisterKeybind(action, description, callback, defaultKey)
	if type(action) == "table" then
		local cfg = action
		action = cfg.name or cfg.id
		description = cfg.description
		callback = cfg.action or cfg.callback or cfg.func
		defaultKey = cfg.defaultKey
	end

	if not action then return false end

	local savedKey = nil
	if PluribusStorageManager and PluribusStorageManager.GetKeybind then
		savedKey = PluribusStorageManager:GetKeybind(action)
	end

	self.keybinds[action] = {
		description = description or action,
		callback = callback,
		defaultKey = defaultKey,
		currentKey = savedKey or defaultKey,
	}

	return true
end

function PluribusCommandRegistry:SetKeybind(action, key)
	if not self.keybinds[action] then
		return false
	end

	if PluribusStorageManager and PluribusStorageManager.SetKeybind then
		PluribusStorageManager:SetKeybind(action, key)
	end
	self.keybinds[action].currentKey = key

	if PluribusMessaging and PLURIBUS_EVENTS and PLURIBUS_EVENTS.KEYBIND_CHANGED then
		PluribusMessaging:Publish(PLURIBUS_EVENTS.KEYBIND_CHANGED, action, key)
	end

	return true
end

function PluribusCommandRegistry:GetKeybind(action)
	return self.keybinds[action] and self.keybinds[action].currentKey or nil
end

function PluribusCommandRegistry:GetAllKeybinds()
	local result = {}
	for action, keybind in pairs(self.keybinds) do
		result[action] = keybind.currentKey
	end
	return result
end

function PluribusCommandRegistry:GetKeybindDescription(action)
	return self.keybinds[action] and self.keybinds[action].description or nil
end

function PluribusCommandRegistry:GetKeybindUIData()
	local result = {}
	for action, keybind in pairs(self.keybinds) do
		table.insert(result, {
			action = action,
			description = keybind.description,
			currentKey = keybind.currentKey or keybind.defaultKey,
			defaultKey = keybind.defaultKey,
		})
	end
	table.sort(result, function(a, b)
		return (a.description or "") < (b.description or "")
	end)
	return result
end

function PluribusCommandRegistry:CheckConflicts()
	local conflicts = {}
	local keyMap = {}
	for action, keybind in pairs(self.keybinds) do
		if keybind.currentKey then
			if keyMap[keybind.currentKey] then
				conflicts[keybind.currentKey] = conflicts[keybind.currentKey] or { keyMap[keybind.currentKey] }
				table.insert(conflicts[keybind.currentKey], action)
			else
				keyMap[keybind.currentKey] = action
			end
		end
	end
	return conflicts
end

function PluribusCommandRegistry:ResetKeybindsToDefault()
	for action, keybind in pairs(self.keybinds) do
		if keybind.defaultKey then
			self:SetKeybind(action, keybind.defaultKey)
		end
	end
end

function PluribusCommandRegistry:GetStatistics()
	local cmdCount, aliasCount, keybindCount, conflictCount = 0, 0, 0, 0
	for _ in pairs(self.commands) do cmdCount = cmdCount + 1 end
	for _ in pairs(self.commandAliases) do aliasCount = aliasCount + 1 end
	for _ in pairs(self.keybinds) do keybindCount = keybindCount + 1 end
	for _ in pairs(self:CheckConflicts()) do conflictCount = conflictCount + 1 end
	return {
		commandCount = cmdCount,
		aliasCount = aliasCount,
		keybindCount = keybindCount,
		conflictCount = conflictCount,
	}
end

_G.PluribusCommandRegistry = PluribusCommandRegistry
return PluribusCommandRegistry
