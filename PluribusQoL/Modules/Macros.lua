-- PluribusQoLMacros Module
-- Manages macro creation and management

PluribusQoLMacros = {}
PluribusQoLMacros.macros = {}
PluribusQoLMacros.shortcuts = {}

function PluribusQoLMacros:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusQoL", "macros", {})
	self.macros = storageData.macros or {}
	self.shortcuts = storageData.shortcuts or {}
	PluribusUtils:Info("QoLMacros module initialized", "PluribusQoL")
end

function PluribusQoLMacros:CreateMacro(macroName, macroBody, icon)
	local macroId = "macro_" .. PluribusUtils:GetTimeStamp()
	
	local macro = {
		id = macroId,
		name = macroName,
		body = macroBody or "",
		icon = icon or "",
		created = PluribusUtils:GetTimeStamp(),
		timesUsed = 0,
	}
	
	self.macros[macroId] = macro
	self:SaveMacros()
	PluribusMessaging:Publish("macro_created", { macro = macroName })
	
	return macro
end

function PluribusQoLMacros:ExecuteMacro(macroId)
	if not self.macros[macroId] then return nil end
	
	self.macros[macroId].timesUsed = (self.macros[macroId].timesUsed or 0) + 1
	self.macros[macroId].lastUsed = PluribusUtils:GetTimeStamp()
	
	self:SaveMacros()
	PluribusMessaging:Publish("macro_executed", { macro = self.macros[macroId].name })
	
	return self.macros[macroId]
end

function PluribusQoLMacros:CreateShortcut(shortcutName, action, keybind)
	local shortcutId = "short_" .. PluribusUtils:GetTimeStamp()
	
	local shortcut = {
		id = shortcutId,
		name = shortcutName,
		action = action,
		keybind = keybind,
		created = PluribusUtils:GetTimeStamp(),
	}
	
	self.shortcuts[shortcutId] = shortcut
	self:SaveMacros()
	PluribusMessaging:Publish("shortcut_created", { shortcut = shortcutName })
	
	return shortcut
end

function PluribusQoLMacros:GetMostUsedMacros(limit)
	limit = limit or 10
	local sorted = {}
	
	for macroId, macro in pairs(self.macros) do
		table.insert(sorted, macro)
	end
	
	table.sort(sorted, function(a, b) 
		return (a.timesUsed or 0) > (b.timesUsed or 0) 
	end)
	
	return { table.unpack(sorted, 1, math.min(limit, #sorted)) }
end

function PluribusQoLMacros:SaveMacros()
	PluribusStorageManager:SetFeatureSetting("PluribusQoL", "macros", {
		macros = self.macros,
		shortcuts = self.shortcuts,
	})
	PluribusDataManager:UpdateSourceData("PluribusQoL", "macros", {
		macros = self.macros,
		shortcuts = self.shortcuts,
	})
end

return PluribusQoLMacros
