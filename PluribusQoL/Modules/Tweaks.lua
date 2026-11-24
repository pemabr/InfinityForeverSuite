-- PluribusQoLTweaks Module
-- Manages UI tweaks and quality-of-life improvements

PluribusQoLTweaks = {}
PluribusQoLTweaks.tweaks = {}
PluribusQoLTweaks.settings = {}

function PluribusQoLTweaks:Initialize()
	local storageData = PluribusStorageManager:GetFeatureSetting("PluribusQoL", "tweaks", {})
	self.tweaks = storageData.tweaks or {}
	self.settings = storageData.settings or {}
	PluribusUtils:Info("QoLTweaks module initialized", "PluribusQoL")
end

function PluribusQoLTweaks:EnableTweak(tweakName, tweakType, description)
	local tweakId = "tweak_" .. PluribusUtils:GetTimeStamp()
	
	local tweak = {
		id = tweakId,
		name = tweakName,
		type = tweakType or "UI",
		description = description or "",
		enabled = true,
		activated = PluribusUtils:GetTimeStamp(),
	}
	
	self.tweaks[tweakId] = tweak
	self:SaveTweaks()
	PluribusMessaging:Publish("tweak_enabled", { tweak = tweakName })
	
	return tweak
end

function PluribusQoLTweaks:DisableTweak(tweakId)
	if not self.tweaks[tweakId] then return nil end
	
	self.tweaks[tweakId].enabled = false
	self.tweaks[tweakId].deactivated = PluribusUtils:GetTimeStamp()
	
	self:SaveTweaks()
	PluribusMessaging:Publish("tweak_disabled", { tweak = self.tweaks[tweakId].name })
	
	return self.tweaks[tweakId]
end

function PluribusQoLTweaks:GetEnabledTweaks()
	local enabled = {}
	for tweakId, tweak in pairs(self.tweaks) do
		if tweak.enabled then
			table.insert(enabled, tweak)
		end
	end
	return enabled
end

function PluribusQoLTweaks:SetSetting(settingName, settingValue)
	self.settings[settingName] = {
		name = settingName,
		value = settingValue,
		updated = PluribusUtils:GetTimeStamp(),
	}
	
	self:SaveTweaks()
	PluribusMessaging:Publish("qol_setting_changed", { setting = settingName, value = settingValue })
	
	return self.settings[settingName]
end

function PluribusQoLTweaks:GetSetting(settingName)
	return self.settings[settingName]
end

function PluribusQoLTweaks:SaveTweaks()
	PluribusStorageManager:SetFeatureSetting("PluribusQoL", "tweaks", {
		tweaks = self.tweaks,
		settings = self.settings,
	})
	PluribusDataManager:UpdateSourceData("PluribusQoL", "tweaks", {
		tweaks = self.tweaks,
		settings = self.settings,
	})
end

return PluribusQoLTweaks
