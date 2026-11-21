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
	if not self.db then self.db = _G.InfinityCoreDB or {} end
	if not self.db.global then self.db.global = {} end
	if not self.db.global.enabledFeatures then self.db.global.enabledFeatures = {} end
	local state = not not enabled
	self.db.global.enabledFeatures[featureName] = state
	if _G.InfinityAddonManager and _G.InfinityAddonManager.addons and _G.InfinityAddonManager.addons[featureName] then
		_G.InfinityAddonManager.addons[featureName].enabled = state
	end
	return true
end

function InfinityStorageManager:IsFeatureEnabled(featureName)
	if not self.db or not self.db.global or not self.db.global.enabledFeatures then
		return false
	end
	local val = self.db.global.enabledFeatures[featureName]
	if val == nil then
		local loaded = false
		if C_AddOns and C_AddOns.IsAddOnLoaded then
			loaded = not not C_AddOns.IsAddOnLoaded(featureName)
		elseif _G.IsAddOnLoaded then
			loaded = not not _G.IsAddOnLoaded(featureName)
		end
		self.db.global.enabledFeatures[featureName] = loaded
		return loaded
	end
	return val == true
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

-- Addon-specific settings
function InfinityStorageManager:SetSetting(category, key, value)
	if not self.db.global.categorySettings then
		self.db.global.categorySettings = {}
	end
	if not self.db.global.categorySettings[category] then
		self.db.global.categorySettings[category] = {}
	end
	self.db.global.categorySettings[category][key] = value
	return true
end

function InfinityStorageManager:GetSetting(category, key, default)
	if self.db.global.categorySettings and 
	   self.db.global.categorySettings[category] and 
	   self.db.global.categorySettings[category][key] ~= nil then
		return self.db.global.categorySettings[category][key]
	end
	return default
end

function InfinityStorageManager:SetAddonSetting(addonName, key, value)
	if not self.db.global.addonSettings then
		self.db.global.addonSettings = {}
	end
	if not self.db.global.addonSettings[addonName] then
		self.db.global.addonSettings[addonName] = {}
	end
	self.db.global.addonSettings[addonName][key] = value
	return true
end

function InfinityStorageManager:GetAddonSetting(addonName, key, default)
	if self.db.global.addonSettings and 
	   self.db.global.addonSettings[addonName] and 
	   self.db.global.addonSettings[addonName][key] ~= nil then
		return self.db.global.addonSettings[addonName][key]
	end
	return default
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
