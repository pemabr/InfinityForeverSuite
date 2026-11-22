-- InfinityData Initialization

local function InitializeData()
	InfinityUtils:Info('InfinityData initializing...', 'InfinityData')
	
	-- Register data sources
	InfinityDataManager:RegisterSource('_Data.toLower()_data')
	
	InfinityUtils:Info('InfinityData initialized successfully', 'InfinityData')
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Central data management",
			author = "Infinity Suite Team",
			category = "Core",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityData" then
		InitializeData()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


