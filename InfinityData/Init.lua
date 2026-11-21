-- InfinityData Initialization

local function InitializeData()
	InfinityUtils:Info('InfinityData initializing...', 'InfinityData')
	
	-- Register data sources
	InfinityDataManager:RegisterSource('infinity_data')
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityData", "1.0.0", {
			description = "Central data management",
			author = "Infinity Suite Team",
			category = "Core",
			enabled = true,
			settings = {}
		})
	end
	
	InfinityUtils:Info('InfinityData initialized successfully', 'InfinityData')
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityData" then
		InitializeData()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


