-- InfinityCore UI Integration
-- Integrates all UI components without requiring chat commands

InfinityUIIntegration = {}

function InfinityUIIntegration:Initialize()
	-- Make sure UI Framework is initialized
	if _G.InfinityUIFramework and _G.InfinityUIFramework.Initialize then
		_G.InfinityUIFramework:Initialize()
	end
	
	-- Initialize Settings Panel
	if _G.InfinitySettingsPanel and _G.InfinitySettingsPanel.Initialize then
		_G.InfinitySettingsPanel:Initialize()
	end
	
	-- Initialize Addon Manager
	if _G.InfinityAddonManager and _G.InfinityAddonManager.Initialize then
		_G.InfinityAddonManager:Initialize()
	end
	
	-- Set up event subscriptions
	if _G.InfinityMessaging then
		_G.InfinityMessaging:Subscribe("INFINITY_SETTING_CHANGED", function(category, key, value)
			InfinityUtils:Info("Setting changed: " .. category .. "." .. key, "UI")
		end)
	end
	
	InfinityUtils:Info("UI Integration initialized", "UIIntegration")
end

-- Add Toggle helper to AddonManager
if InfinityAddonManager then
	function InfinityAddonManager:Toggle()
		if _G.InfinityAddonManagerWindow then
			if _G.InfinityAddonManagerWindow:IsVisible() then
				_G.InfinityAddonManagerWindow:Hide()
			else
				_G.InfinityAddonManagerWindow:Show()
			end
		else
			local window = self:CreateManagerWindow()
			window:Show()
		end
	end
end

return InfinityUIIntegration
