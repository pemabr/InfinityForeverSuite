-- InfinityCore Settings Panel (placeholder for future expansion)

InfinitySettingsPanel = {}

function InfinitySettingsPanel:Initialize()
	InfinityUtils:Info("Settings Panel initialized", "SettingsPanel")
end

function InfinitySettingsPanel:ShowFeatureSettings(featureName)
	local settings = InfinityStorageManager:GetFeatureSettings(featureName)
	InfinityUtils:Info("Showing settings for feature: " .. featureName, "SettingsPanel")
	return settings
end

return InfinitySettingsPanel
