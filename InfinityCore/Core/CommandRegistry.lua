-- InfinityCore Command Registry
-- Centralized slash command and keybind management

InfinityCommandRegistry = {
	commands = {},
	keybinds = {},
	commandAliases = {},
}

-- Register a slash command
function InfinityCommandRegistry:RegisterCommand(command, callback, aliases)
	if type(command) == "table" then
		local opts = command
		command = opts.name
		callback = opts.func or opts.callback
		aliases = opts.aliases
	end
	if type(command) ~= "string" or command == "" then
		return false
	end
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

local keybindOwner = CreateFrame("Frame", "InfinityKeybindOwner")
local keybindButtons = {}

local function GetOrCreateKeybindButton(action, callback)
	if not keybindButtons[action] then
		local safeName = "InfinityKeybindBtn_" .. tostring(action):gsub("[^%w_]", "_")
		local btn = CreateFrame("Button", safeName, UIParent)
		btn:RegisterForClicks("AnyUp", "AnyDown")
		keybindButtons[action] = btn
	end
	local btn = keybindButtons[action]
	btn:SetScript("OnClick", function(_, _, down)
		if down == false or down == nil then
			local entry = InfinityCommandRegistry.keybinds[action]
			local fn = (entry and entry.callback) or callback
			if type(fn) == "function" then
				local ok, err = pcall(fn)
				if not ok and _G.InfinityUtils then
					_G.InfinityUtils:Error("Keybind error (" .. tostring(action) .. "): " .. tostring(err), "CommandRegistry")
				end
			end
		end
	end)
	return btn
end

function InfinityCommandRegistry:ApplyAllKeybinds()
	if InCombatLockdown and InCombatLockdown() then
		return false
	end
	if _G.ClearOverrideBindings then
		_G.ClearOverrideBindings(keybindOwner)
	end
	for action, keybind in pairs(self.keybinds) do
		local key = keybind.currentKey or keybind.defaultKey
		if key and key ~= "" and type(keybind.callback) == "function" then
			local btn = GetOrCreateKeybindButton(action, keybind.callback)
			if _G.SetOverrideBindingClick then
				_G.SetOverrideBindingClick(keybindOwner, true, key, btn:GetName(), "LeftButton")
			end
		end
	end
	return true
end

keybindOwner:RegisterEvent("PLAYER_LOGIN")
keybindOwner:RegisterEvent("UPDATE_BINDINGS")
keybindOwner:SetScript("OnEvent", function()
	InfinityCommandRegistry:ApplyAllKeybinds()
end)

-- Register a keybind
function InfinityCommandRegistry:RegisterKeybind(action, description, callback, defaultKey)
	if type(action) == "table" then
		local opts = action
		action = opts.name
		description = opts.description
		callback = opts.action or opts.callback or opts.func
		defaultKey = opts.defaultKey
	end
	if type(action) ~= "string" or action == "" then
		return false
	end
	local savedKey = InfinityStorageManager and InfinityStorageManager:GetKeybind(action)
	self.keybinds[action] = {
		description = description or action,
		callback = callback,
		defaultKey = defaultKey,
		currentKey = (savedKey ~= nil and savedKey) or defaultKey,
	}
	
	GetOrCreateKeybindButton(action, callback)
	if self.keybinds[action].currentKey and self.keybinds[action].currentKey ~= "" then
		self:ApplyAllKeybinds()
	end
	
	InfinityUtils:Info("Keybind registered: " .. action, "CommandRegistry")
	return true
end

-- Set/change a keybind
function InfinityCommandRegistry:SetKeybind(action, key)
	if not self.keybinds[action] then
		return false
	end
	
	-- Store in persistent storage (empty string = explicitly unbound)
	local stored = (key and key ~= "") and key or ""
	if InfinityStorageManager then
		InfinityStorageManager:SetKeybind(action, stored)
	end
	self.keybinds[action].currentKey = stored
	self:ApplyAllKeybinds()
	
	-- Notify subscribers
	if InfinityMessaging then
		InfinityMessaging:Publish(INFINITY_EVENTS.KEYBIND_CHANGED, action, stored)
	end
	
	InfinityUtils:Info("Keybind updated: " .. action .. " = " .. (stored ~= "" and stored or "(unbound)"), "CommandRegistry")
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
		local cur = keybind.currentKey
		if cur == nil then
			cur = keybind.defaultKey
		elseif cur == "" then
			cur = nil
		end
		table.insert(result, {
			action = action,
			description = keybind.description or action,
			currentKey = cur,
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
