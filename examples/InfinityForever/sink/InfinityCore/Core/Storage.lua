-- InfinityCore Storage Manager
-- Handles persistent data storage via SavedVariables

InfinityStorageManager = {
	db = nil,
	defaults = {
		global = {
			version = INFINITY_SUITE_VERSION,
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
function InfinityStorageManager:Initialize(savedVarsTable)
	self.db = savedVarsTable or {}
	
	-- Set up default structure if empty
	if not self.db.global then
		self.db.global = InfinityUtils:DeepCopy(self.defaults.global)
	end
	
	if not self.db.profile then
		self.db.profile = InfinityUtils:DeepCopy(self.defaults.profile)
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
	
	InfinityUtils:Info("Storage initialized", "StorageManager")
	return true
end

-- Get the entire database
function InfinityStorageManager:GetDB()
	return self.db
end

-- Global storage operations
function InfinityStorageManager:SetGlobal(key, value)
	if not self.db.global then
		self.db.global = {}
	end
	self.db.global[key] = value
	return true
end

function InfinityStorageManager:GetGlobal(key, default)
	if self.db.global and self.db.global[key] ~= nil then
		return self.db.global[key]
	end
	return default
end

-- Feature settings
function InfinityStorageManager:SetFeatureSetting(featureName, key, value)
	if not self.db.global.settings[featureName] then
		self.db.global.settings[featureName] = {}
	end
	self.db.global.settings[featureName][key] = value
	return true
end

function InfinityStorageManager:GetFeatureSetting(featureName, key, default)
	if self.db.global.settings[featureName] and self.db.global.settings[featureName][key] ~= nil then
		return self.db.global.settings[featureName][key]
	end
	return default
end

function InfinityStorageManager:GetFeatureSettings(featureName)
	return self.db.global.settings[featureName] or {}
end

-- Feature enabled/disabled
function InfinityStorageManager:SetFeatureEnabled(featureName, enabled)
	self.db.global.enabledFeatures[featureName] = enabled
	return true
end

function InfinityStorageManager:IsFeatureEnabled(featureName)
	return self.db.global.enabledFeatures[featureName] == true
end

function InfinityStorageManager:GetEnabledFeatures()
	local enabled = {}
	for name, isEnabled in pairs(self.db.global.enabledFeatures) do
		if isEnabled then
			table.insert(enabled, name)
		end
	end
	return enabled
end

-- Keybind storage
function InfinityStorageManager:SetKeybind(action, keybind)
	self.db.global.keybinds[action] = keybind
	return true
end

function InfinityStorageManager:GetKeybind(action)
	return self.db.global.keybinds[action]
end

function InfinityStorageManager:GetKeybinds()
	return InfinityUtils:DeepCopy(self.db.global.keybinds)
end

-- Profile-specific settings
function InfinityStorageManager:SetProfile(key, value)
	if not self.db.profile then
		self.db.profile = {}
	end
	self.db.profile[key] = value
	return true
end

function InfinityStorageManager:GetProfile(key, default)
	if self.db.profile and self.db.profile[key] ~= nil then
		return self.db.profile[key]
	end
	return default
end

-- Character-specific storage
function InfinityStorageManager:SetCharacter(key, value)
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

function InfinityStorageManager:GetCharacter(key, default)
	local charName = UnitName("player")
	local charRealm = GetRealmName()
	local charKey = charName .. "-" .. charRealm
	
	if self.db.characters and self.db.characters[charKey] and self.db.characters[charKey][key] ~= nil then
		return self.db.characters[charKey][key]
	end
	return default
end

-- Migration/Reset utilities
function InfinityStorageManager:ResetFeatureSettings(featureName)
	self.db.global.settings[featureName] = nil
	self.db.global.enabledFeatures[featureName] = nil
	InfinityUtils:Info("Settings reset for feature: " .. featureName, "StorageManager")
	return true
end

function InfinityStorageManager:ResetAll()
	self.db = InfinityUtils:DeepCopy(self.defaults)
	InfinityUtils:Warning("All settings reset to defaults!", "StorageManager")
	return true
end

-- Get database statistics
function InfinityStorageManager:GetStatistics()
	local stats = {
		storageSize = 0,
		featureCount = 0,
		characterCount = 0,
	}
	
	stats.featureCount = InfinityUtils:IsValidTable(self.db.global.settings) and #self.db.global.settings or 0
	stats.characterCount = InfinityUtils:IsValidTable(self.db.characters) and #self.db.characters or 0
	
	return stats
end

return InfinityStorageManager
