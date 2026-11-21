-- InfinityQoLMacros Module
-- Manages macro creation and management

InfinityQoLMacros = {}
InfinityQoLMacros.macros = {}
InfinityQoLMacros.shortcuts = {}

function InfinityQoLMacros:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityQoL", "macros", {})
	self.macros = storageData.macros or {}
	self.shortcuts = storageData.shortcuts or {}
	InfinityUtils:Info("QoLMacros module initialized", "InfinityQoL")
end

function InfinityQoLMacros:CreateMacro(macroName, macroBody, icon)
	local macroId = "macro_" .. InfinityUtils:GetTimeStamp()
	
	local macro = {
		id = macroId,
		name = macroName,
		body = macroBody or "",
		icon = icon or "",
		created = InfinityUtils:GetTimeStamp(),
		timesUsed = 0,
	}
	
	self.macros[macroId] = macro
	self:SaveMacros()
	InfinityMessaging:Publish("macro_created", { macro = macroName })
	
	return macro
end

function InfinityQoLMacros:ExecuteMacro(macroId)
	if not self.macros[macroId] then return nil end
	
	self.macros[macroId].timesUsed = (self.macros[macroId].timesUsed or 0) + 1
	self.macros[macroId].lastUsed = InfinityUtils:GetTimeStamp()
	
	self:SaveMacros()
	InfinityMessaging:Publish("macro_executed", { macro = self.macros[macroId].name })
	
	return self.macros[macroId]
end

function InfinityQoLMacros:CreateShortcut(shortcutName, action, keybind)
	local shortcutId = "short_" .. InfinityUtils:GetTimeStamp()
	
	local shortcut = {
		id = shortcutId,
		name = shortcutName,
		action = action,
		keybind = keybind,
		created = InfinityUtils:GetTimeStamp(),
	}
	
	self.shortcuts[shortcutId] = shortcut
	self:SaveMacros()
	InfinityMessaging:Publish("shortcut_created", { shortcut = shortcutName })
	
	return shortcut
end

function InfinityQoLMacros:GetMostUsedMacros(limit)
	limit = limit or 10
	local sorted = {}
	
	for macroId, macro in pairs(self.macros) do
		table.insert(sorted, macro)
	end
	
	table.sort(sorted, function(a, b) 
		return (a.timesUsed or 0) > (b.timesUsed or 0) 
	end)
	
	return { unpack(sorted, 1, math.min(limit, #sorted)) }
end

function InfinityQoLMacros:SaveMacros()
	InfinityStorageManager:SetFeatureSetting("InfinityQoL", "macros", {
		macros = self.macros,
		shortcuts = self.shortcuts,
	})
	InfinityDataManager:UpdateSourceData("InfinityQoL", "macros", {
		macros = self.macros,
		shortcuts = self.shortcuts,
	})
end

return InfinityQoLMacros
