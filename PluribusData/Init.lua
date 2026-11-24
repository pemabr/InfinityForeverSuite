-- PluribusData Initialization

local function InitializeData()
	PluribusUtils:Info('PluribusData initializing...', 'PluribusData')
	
	-- Register data sources
	PluribusDataManager:RegisterSource('_Data.toLower()_data')
	
	PluribusUtils:Info('PluribusData initialized successfully', 'PluribusData')
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Central data management",
			author = "Pluribus Suite Team",
			category = "Core",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusData" then
		InitializeData()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


