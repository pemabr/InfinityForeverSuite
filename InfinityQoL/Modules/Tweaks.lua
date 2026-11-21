-- InfinityQoLTweaks Module
-- Manages UI tweaks and quality-of-life improvements

InfinityQoLTweaks = {}
InfinityQoLTweaks.tweaks = {}
InfinityQoLTweaks.settings = {}

function InfinityQoLTweaks:Initialize()
	local storageData = InfinityStorageManager:GetFeatureSetting("InfinityQoL", "tweaks", {})
	self.tweaks = storageData.tweaks or {}
	self.settings = storageData.settings or {}
	InfinityUtils:Info("QoLTweaks module initialized", "InfinityQoL")
end

function InfinityQoLTweaks:EnableTweak(tweakName, tweakType, description)
	local tweakId = "tweak_" .. InfinityUtils:GetTimeStamp()
	
	local tweak = {
		id = tweakId,
		name = tweakName,
		type = tweakType or "UI",
		description = description or "",
		enabled = true,
		activated = InfinityUtils:GetTimeStamp(),
	}
	
	self.tweaks[tweakId] = tweak
	self:SaveTweaks()
	InfinityMessaging:Publish("tweak_enabled", { tweak = tweakName })
	
	return tweak
end

function InfinityQoLTweaks:DisableTweak(tweakId)
	if not self.tweaks[tweakId] then return nil end
	
	self.tweaks[tweakId].enabled = false
	self.tweaks[tweakId].deactivated = InfinityUtils:GetTimeStamp()
	
	self:SaveTweaks()
	InfinityMessaging:Publish("tweak_disabled", { tweak = self.tweaks[tweakId].name })
	
	return self.tweaks[tweakId]
end

function InfinityQoLTweaks:GetEnabledTweaks()
	local enabled = {}
	for tweakId, tweak in pairs(self.tweaks) do
		if tweak.enabled then
			table.insert(enabled, tweak)
		end
	end
	return enabled
end

function InfinityQoLTweaks:SetSetting(settingName, settingValue)
	self.settings[settingName] = {
		name = settingName,
		value = settingValue,
		updated = InfinityUtils:GetTimeStamp(),
	}
	
	self:SaveTweaks()
	InfinityMessaging:Publish("qol_setting_changed", { setting = settingName, value = settingValue })
	
	return self.settings[settingName]
end

function InfinityQoLTweaks:GetSetting(settingName)
	return self.settings[settingName]
end

function InfinityQoLTweaks:SaveTweaks()
	InfinityStorageManager:SetFeatureSetting("InfinityQoL", "tweaks", {
		tweaks = self.tweaks,
		settings = self.settings,
	})
	InfinityDataManager:UpdateSourceData("InfinityQoL", "tweaks", {
		tweaks = self.tweaks,
		settings = self.settings,
	})
end

return InfinityQoLTweaks
