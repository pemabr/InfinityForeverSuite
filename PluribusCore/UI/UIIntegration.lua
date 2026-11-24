-- PluribusCore UI Integration
-- Integrates all UI components without requiring chat commands

PluribusUIIntegration = {}

function PluribusUIIntegration:Initialize()
	-- Make sure UI Framework is initialized
	if _G.PluribusUIFramework and _G.PluribusUIFramework.Initialize then
		_G.PluribusUIFramework:Initialize()
	end
	
	-- Initialize Settings Panel
	if _G.PluribusSettingsPanel and _G.PluribusSettingsPanel.Initialize then
		_G.PluribusSettingsPanel:Initialize()
	end
	
	-- Initialize Addon Manager
	if _G.PluribusAddonManager and _G.PluribusAddonManager.Initialize then
		_G.PluribusAddonManager:Initialize()
	end
	
	-- Set up event subscriptions
	if _G.PluribusMessaging then
		_G.PluribusMessaging:Subscribe("PLURIBUS_SETTING_CHANGED", function(category, key, value)
			PluribusUtils:Info("Setting changed: " .. category .. "." .. key, "UI")
		end)
	end
	
	PluribusUtils:Info("UI Integration initialized", "UIIntegration")
end

-- Add Toggle helper to AddonManager
if PluribusAddonManager then
	function PluribusAddonManager:Toggle()
		if _G.PluribusAddonManagerWindow then
			if _G.PluribusAddonManagerWindow:IsVisible() then
				_G.PluribusAddonManagerWindow:Hide()
			else
				_G.PluribusAddonManagerWindow:Show()
			end
		else
			local window = self:CreateManagerWindow()
			window:Show()
		end
	end
end

return PluribusUIIntegration
