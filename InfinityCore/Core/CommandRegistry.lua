-- InfinityCore Command Registry
-- Centralized slash command and keybind management

InfinityCommandRegistry = {
	commands = {},
	keybinds = {},
	commandAliases = {},
}

-- Register a slash command
function InfinityCommandRegistry:RegisterCommand(command, callback, aliases)
	command = string.lower(command)
	
	-- Store the main command
	self.commands[command] = callback
	
	-- Register slash command with WoW
	_G["SLASH_INFINITY_" .. string.upper(command)] = "/" .. command
	SlashCmdList["INFINITY_" .. string.upper(command)] = function(msg)
		local args = InfinityUtils:Split(msg, " ")
		pcall(callback, args, msg)
	end
	
	-- Register aliases
	if aliases and type(aliases) == "table" then
		for _, alias in ipairs(aliases) do
			alias = string.lower(alias)
			self.commandAliases[alias] = command
			_G["SLASH_INFINITY_" .. string.upper(alias)] = "/" .. alias
			SlashCmdList["INFINITY_" .. string.upper(alias)] = function(msg)
				local args = InfinityUtils:Split(msg, " ")
				pcall(callback, args, msg)
			end
		end
	end
	
	InfinityUtils:Info("Command registered: /" .. command, "CommandRegistry")
	return true
end

-- Get a registered command
function InfinityCommandRegistry:GetCommand(command)
	command = string.lower(command)
	
	-- Check if it's an alias
	if self.commandAliases[command] then
		command = self.commandAliases[command]
	end
	
	return self.commands[command]
end

-- Register a keybind
function InfinityCommandRegistry:RegisterKeybind(action, description, callback, defaultKey)
	self.keybinds[action] = {
		description = description,
		callback = callback,
		defaultKey = defaultKey,
		currentKey = InfinityStorageManager:GetKeybind(action) or defaultKey,
	}
	
	-- Set up the actual keybind binding
	if self.keybinds[action].currentKey then
		self:SetKeybind(action, self.keybinds[action].currentKey)
	end
	
	InfinityUtils:Info("Keybind registered: " .. action, "CommandRegistry")
	return true
end

-- Set/change a keybind
function InfinityCommandRegistry:SetKeybind(action, key)
	if not self.keybinds[action] then
		return false
	end
	
	-- Store in persistent storage
	InfinityStorageManager:SetKeybind(action, key)
	self.keybinds[action].currentKey = key
	
	-- Notify subscribers
	InfinityMessaging:Publish(INFINITY_EVENTS.KEYBIND_CHANGED, action, key)
	
	InfinityUtils:Info("Keybind updated: " .. action .. " = " .. key, "CommandRegistry")
	return true
end

-- Get a keybind
function InfinityCommandRegistry:GetKeybind(action)
	if self.keybinds[action] then
		return self.keybinds[action].currentKey
	end
	return nil
end

-- Get all keybinds
function InfinityCommandRegistry:GetAllKeybinds()
	local result = {}
	for action, keybind in pairs(self.keybinds) do
		result[action] = keybind.currentKey
	end
	return result
end

-- Get keybind description
function InfinityCommandRegistry:GetKeybindDescription(action)
	if self.keybinds[action] then
		return self.keybinds[action].description
	end
	return nil
end

-- Get all keybind descriptions for UI
function InfinityCommandRegistry:GetKeybindUIData()
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
		return a.description < b.description
	end)
	return result
end

-- Check for keybind conflicts
function InfinityCommandRegistry:CheckConflicts()
	local conflicts = {}
	local keyMap = {}
	
	for action, keybind in pairs(self.keybinds) do
		if keybind.currentKey then
			if keyMap[keybind.currentKey] then
				if not conflicts[keybind.currentKey] then
					conflicts[keybind.currentKey] = {}
				end
				table.insert(conflicts[keybind.currentKey], action)
				table.insert(conflicts[keybind.currentKey], keyMap[keybind.currentKey])
			else
				keyMap[keybind.currentKey] = action
			end
		end
	end
	
	return conflicts
end

-- Reset keybinds to defaults
function InfinityCommandRegistry:ResetKeybindsToDefault()
	for action, keybind in pairs(self.keybinds) do
		if keybind.defaultKey then
			self:SetKeybind(action, keybind.defaultKey)
		end
	end
	InfinityUtils:Info("All keybinds reset to defaults", "CommandRegistry")
end

-- Get statistics
function InfinityCommandRegistry:GetStatistics()
	local stats = {
		commandCount = 0,
		aliasCount = 0,
		keybindCount = 0,
		conflictCount = 0,
	}
	
	stats.commandCount = InfinityUtils:IsValidTable(self.commands) and #self.commands or 0
	stats.aliasCount = InfinityUtils:IsValidTable(self.commandAliases) and #self.commandAliases or 0
	stats.keybindCount = InfinityUtils:IsValidTable(self.keybinds) and #self.keybinds or 0
	
	local conflicts = self:CheckConflicts()
	for _, v in pairs(conflicts) do
		stats.conflictCount = stats.conflictCount + 1
	end
	
	return stats
end

return InfinityCommandRegistry
