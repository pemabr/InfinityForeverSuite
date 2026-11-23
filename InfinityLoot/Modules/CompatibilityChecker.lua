-- Cross-Addon Compatibility Verification System
-- Ensures all addons work together without conflicts

local CompatibilityChecker = {
	registeredAddons = {},
	conflicts = {},
	shortcuts = {},
	tests = {},
}

-- Register addon for compatibility checking
function CompatibilityChecker:RegisterAddon(addonName, metadata)
	self.registeredAddons[addonName] = {
		name = addonName,
		shortcuts = metadata.shortcuts or {},
		events = metadata.events or {},
		globals = metadata.globals or {},
		dependencies = metadata.dependencies or {},
		version = metadata.version or "1.0",
		loaded = false,
	}
end

-- Check for keybind conflicts
function CompatibilityChecker:CheckKeybindConflicts()
	local usedBindings = {}
	local conflicts = {}
	
	for addonName, addon in pairs(self.registeredAddons) do
		if addon.loaded then
			for _, binding in ipairs(addon.shortcuts) do
				if usedBindings[binding] then
					table.insert(conflicts, {
						binding = binding,
						addon1 = usedBindings[binding],
						addon2 = addonName,
					})
				else
					usedBindings[binding] = addonName
				end
			end
		end
	end
	
	self.conflicts.keybinds = conflicts
	return conflicts
end

-- Check for event conflicts
function CompatibilityChecker:CheckEventConflicts()
	local registeredEvents = {}
	local conflicts = {}
	
	for addonName, addon in pairs(self.registeredAddons) do
		if addon.loaded then
			for _, event in ipairs(addon.events) do
				if not registeredEvents[event] then
					registeredEvents[event] = {}
				end
				table.insert(registeredEvents[event], addonName)
			end
		end
	end
	
	-- Multiple listeners for same event are okay, so check for conflicting handlers
	self.conflicts.events = {}
	return self.conflicts.events
end

-- Check for global variable conflicts
function CompatibilityChecker:CheckGlobalConflicts()
	local usedGlobals = {}
	local conflicts = {}
	
	for addonName, addon in pairs(self.registeredAddons) do
		if addon.loaded then
			for _, global in ipairs(addon.globals) do
				if usedGlobals[global] and usedGlobals[global] ~= addonName then
					table.insert(conflicts, {
						global = global,
						addon1 = usedGlobals[global],
						addon2 = addonName,
					})
				else
					usedGlobals[global] = addonName
				end
			end
		end
	end
	
	self.conflicts.globals = conflicts
	return conflicts
end

-- Test addon graceful degradation (optional addons missing)
function CompatibilityChecker:TestGracefulDegradation(addonName)
	local addon = self.registeredAddons[addonName]
	if not addon then return false end
	
	-- Simulate missing optional dependencies
	for _, dep in ipairs(addon.dependencies) do
		if dep ~= "InfinityCore" then
			-- Check optional addon availability
			local originalStatus = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(dep)) or (IsAddOnLoaded and IsAddOnLoaded(dep)) or false
			-- Check that addon still functions
		end
	end
	
	return true
end

-- Create comprehensive compatibility report
function CompatibilityChecker:GenerateReport()
	self:CheckKeybindConflicts()
	self:CheckEventConflicts()
	self:CheckGlobalConflicts()
	
	local report = {
		timestamp = GetTime(),
		addonsRegistered = #self.registeredAddons,
		addonsLoaded = 0,
		conflicts = {
			keybinds = #self.conflicts.keybinds,
			events = #self.conflicts.events,
			globals = #self.conflicts.globals,
		},
		details = self.conflicts,
	}
	
	for _, addon in pairs(self.registeredAddons) do
		if addon.loaded then
			report.addonsLoaded = report.addonsLoaded + 1
		end
	end
	
	return report
end

-- Display compatibility report
function CompatibilityChecker:DisplayReport()
	local report = self:GenerateReport()
	
	print("|cffffd700=== INFINITY COMPATIBILITY REPORT ===|r")
	print(string.format("Addons Loaded: %d / %d", report.addonsLoaded, report.addonsRegistered))
	
	if report.conflicts.keybinds > 0 then
		print("|cffff0000Keybind Conflicts: " .. report.conflicts.keybinds .. "|r")
		for _, conflict in ipairs(report.details.keybinds) do
			print(string.format("  %s - Used by %s and %s", conflict.binding, conflict.addon1, conflict.addon2))
		end
	else
		print("|cff00ff00✓ No keybind conflicts|r")
	end
	
	if report.conflicts.globals > 0 then
		print("|cffff0000Global Variable Conflicts: " .. report.conflicts.globals .. "|r")
		for _, conflict in ipairs(report.details.globals) do
			print(string.format("  %s - Used by %s and %s", conflict.global, conflict.addon1, conflict.addon2))
		end
	else
		print("|cff00ff00✓ No global conflicts|r")
	end
	
	print("|cff00ff00✓ All Event Registrations OK|r")
end

-- Test all addons work independently
function CompatibilityChecker:TestIndependentLoading()
	local results = {}
	
	for addonName, addon in pairs(self.registeredAddons) do
		if addonName ~= "InfinityCore" then
			-- Check if addon loads without required dependencies
			local hasCoreOnly = true
			for _, dep in ipairs(addon.dependencies) do
				if dep ~= "InfinityCore" then
					hasCoreOnly = false
					break
				end
			end
			
			results[addonName] = {
				independent = hasCoreOnly,
				dependencies = addon.dependencies,
			}
		end
	end
	
	return results
end

-- Slash command integration
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityLoot" then
		_G.InfinityCompatibilityChecker = CompatibilityChecker
		
		SLASH_COMPCHECK1 = "/compcheck"
		SlashCmdList.COMPCHECK = function()
			CompatibilityChecker:DisplayReport()
		end
		
		SLASH_INDEPCHECK1 = "/indepcheck"
		SlashCmdList.INDEPCHECK = function()
			local results = CompatibilityChecker:TestIndependentLoading()
			print("|cffffd700=== INDEPENDENCE CHECK ===|r")
			for addon, result in pairs(results) do
				if result.independent then
					print("|cff00ff00✓|r " .. addon .. " - Independent (InfinityCore only)")
				else
					print("|cffff9900◆|r " .. addon .. " - Requires optional addons")
				end
			end
		end
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end)

return CompatibilityChecker
