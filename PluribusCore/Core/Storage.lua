-- PluribusCore Storage Manager
-- Handles persistent data storage via SavedVariables

PluribusStorageManager = {
	db = nil,
	defaults = {
		global = {
			version = PLURIBUS_SUITE_VERSION,
			enabledFeatures = {},
			settings = {},
			keybinds = {},
		},
		profile = {
			theme = "default",
			minimap = { enabled = true },
			notifications = { enabled = true },
		},
	},
}

-- Initialize storage
function PluribusStorageManager:Initialize(savedVarsTable)
	self.db = savedVarsTable or {}
	
	-- Set up default structure if empty
	if not self.db.global then
		self.db.global = PluribusUtils:DeepCopy(self.defaults.global)
	end
	
	if not self.db.profile then
		self.db.profile = PluribusUtils:DeepCopy(self.defaults.profile)
	end
	
	-- Initialize feature flags if not present
	if not self.db.global.enabledFeatures then
		self.db.global.enabledFeatures = {}
	end
	
	-- Initialize settings if not present
	if not self.db.global.settings then
		self.db.global.settings = {}
	end
	
	-- Initialize keybinds if not present
	if not self.db.global.keybinds then
		self.db.global.keybinds = {}
	end
	
	PluribusUtils:Info("Storage initialized", "StorageManager")
	return true
end

-- Get the entire database
function PluribusStorageManager:GetDB()
	return self.db
end

-- Global storage operations
function PluribusStorageManager:SetGlobal(key, value)
	if not self.db.global then
		self.db.global = {}
	end
	self.db.global[key] = value
	return true
end

function PluribusStorageManager:GetGlobal(key, default)
	if self.db.global and self.db.global[key] ~= nil then
		return self.db.global[key]
	end
	return default
end

-- Feature settings
function PluribusStorageManager:SetFeatureSetting(featureName, key, value)
	if not self.db.global.settings[featureName] then
		self.db.global.settings[featureName] = {}
	end
	self.db.global.settings[featureName][key] = value
	return true
end

function PluribusStorageManager:GetFeatureSetting(featureName, key, default)
	if self.db.global.settings[featureName] and self.db.global.settings[featureName][key] ~= nil then
		return self.db.global.settings[featureName][key]
	end
	return default
end

function PluribusStorageManager:GetFeatureSettings(featureName)
	return self.db.global.settings[featureName] or {}
end

-- Feature enabled/disabled
function PluribusStorageManager:SetFeatureEnabled(featureName, enabled)
	self.db.global.enabledFeatures[featureName] = enabled
	return true
end

function PluribusStorageManager:IsFeatureEnabled(featureName)
	return self.db.global.enabledFeatures[featureName] == true
end

function PluribusStorageManager:GetEnabledFeatures()
	local enabled = {}
	for name, isEnabled in pairs(self.db.global.enabledFeatures) do
		if isEnabled then
			table.insert(enabled, name)
		end
	end
	return enabled
end

-- Addon-specific settings
function PluribusStorageManager:SetSetting(category, key, value)
	if not self.db.global.categorySettings then
		self.db.global.categorySettings = {}
	end
	if not self.db.global.categorySettings[category] then
		self.db.global.categorySettings[category] = {}
	end
	self.db.global.categorySettings[category][key] = value
	return true
end

function PluribusStorageManager:GetSetting(category, key, default)
	if self.db.global.categorySettings and 
	   self.db.global.categorySettings[category] and 
	   self.db.global.categorySettings[category][key] ~= nil then
		return self.db.global.categorySettings[category][key]
	end
	return default
end

function PluribusStorageManager:SetAddonSetting(addonName, key, value)
	if not self.db.global.addonSettings then
		self.db.global.addonSettings = {}
	end
	if not self.db.global.addonSettings[addonName] then
		self.db.global.addonSettings[addonName] = {}
	end
	self.db.global.addonSettings[addonName][key] = value
	return true
end

function PluribusStorageManager:GetAddonSetting(addonName, key, default)
	if self.db.global.addonSettings and 
	   self.db.global.addonSettings[addonName] and 
	   self.db.global.addonSettings[addonName][key] ~= nil then
		return self.db.global.addonSettings[addonName][key]
	end
	return default
end

-- Keybind storage
function PluribusStorageManager:SetKeybind(action, keybind)
	self.db.global.keybinds[action] = keybind
	return true
end

function PluribusStorageManager:GetKeybind(action)
	return self.db.global.keybinds[action]
end

function PluribusStorageManager:GetKeybinds()
	return PluribusUtils:DeepCopy(self.db.global.keybinds)
end

-- Profile-specific settings
function PluribusStorageManager:SetProfile(key, value)
	if not self.db.profile then
		self.db.profile = {}
	end
	self.db.profile[key] = value
	return true
end

function PluribusStorageManager:GetProfile(key, default)
	if self.db.profile and self.db.profile[key] ~= nil then
		return self.db.profile[key]
	end
	return default
end

-- Character-specific storage
function PluribusStorageManager:SetCharacter(key, value)
	local charName = UnitName("player")
	local charRealm = GetRealmName()
	local charKey = charName .. "-" .. charRealm
	
	if not self.db.characters then
		self.db.characters = {}
	end
	
	if not self.db.characters[charKey] then
		self.db.characters[charKey] = {}
	end
	
	self.db.characters[charKey][key] = value
	return true
end

function PluribusStorageManager:GetCharacter(key, default)
	local charName = UnitName("player")
	local charRealm = GetRealmName()
	local charKey = charName .. "-" .. charRealm
	
	if self.db.characters and self.db.characters[charKey] and self.db.characters[charKey][key] ~= nil then
		return self.db.characters[charKey][key]
	end
	return default
end

-- Migration/Reset utilities
function PluribusStorageManager:ResetFeatureSettings(featureName)
	self.db.global.settings[featureName] = nil
	self.db.global.enabledFeatures[featureName] = nil
	PluribusUtils:Info("Settings reset for feature: " .. featureName, "StorageManager")
	return true
end

function PluribusStorageManager:ResetAll()
	self.db = PluribusUtils:DeepCopy(self.defaults)
	PluribusUtils:Warning("All settings reset to defaults!", "StorageManager")
	return true
end

-- Get database statistics
function PluribusStorageManager:GetStatistics()
	local stats = {
		storageSize = 0,
		featureCount = 0,
		characterCount = 0,
	}
	
	stats.featureCount = PluribusUtils:IsValidTable(self.db.global.settings) and #self.db.global.settings or 0
	stats.characterCount = PluribusUtils:IsValidTable(self.db.characters) and #self.db.characters or 0
	
	return stats
end

return PluribusStorageManager
