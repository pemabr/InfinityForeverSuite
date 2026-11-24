-- PluribusInventory Initialization

local function InitializeInventory()
	PluribusUtils:Info("PluribusInventory initializing...", "Inventory")
	
	if not PluribusCore or not PluribusDataManager then
		PluribusUtils:Warning("PluribusCore not ready", "Inventory")
		return
	end
	
	-- Initialize modules
	if PluribusBagTracker then pcall(function() PluribusBagTracker:Initialize() end) end
	if PluribusItemTracking then pcall(function() PluribusItemTracking:Initialize() end) end
	if PluribusCraftingIntegration then pcall(function() PluribusCraftingIntegration:Initialize() end) end
	if PluribusVendorPricing then pcall(function() PluribusVendorPricing:Initialize() end) end
	if PluribusInventoryUI then pcall(function() PluribusInventoryUI:Initialize() end) end
	
	-- Register globals
	_G.PluribusBagTracker = PluribusBagTracker
	_G.PluribusItemTracking = PluribusItemTracking
	_G.PluribusCraftingIntegration = PluribusCraftingIntegration
	_G.PluribusVendorPricing = PluribusVendorPricing
	_G.PluribusInventoryUI = PluribusInventoryUI
	
	-- Slash commands (never shadow WoW's /inv party invite command)
	PluribusCommandRegistry:RegisterCommand("plbbags", function(args)
		if not args or #args == 0 then
			if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
				_G.PluribusMainFrame:OpenToTab("Bags & Bank")
			elseif PluribusInventoryUI then
				PluribusInventoryUI:Toggle()
			end
		elseif args[1] == "scan" then
			PluribusBagTracker:ScanBags()
			PluribusUtils:Info("Bags scanned", "Inventory")
		elseif args[1] == "value" then
			local value = PluribusVendorPricing:CalculateBagValue()
			PluribusUtils:Info("Total bag value: " .. PluribusUtils:FormatGold(value), "Inventory")
		elseif args[1] == "free" then
			local free = PluribusBagTracker:GetFreeSlots()
			PluribusUtils:Info("Free slots: " .. free, "Inventory")
		elseif args[1] == "item" and args[2] then
			local count = PluribusBagTracker:GetItemCount(tonumber(args[2]))
			PluribusUtils:Info("Item count: " .. count, "Inventory")
		end
	end, { "inventory" })
	
	PluribusUtils:Info("PluribusInventory initialized successfully", "Inventory")
	PluribusMessaging:Publish(PLURIBUS_EVENTS.FEATURE_ENABLED, "inventory", true)
end


local function RegisterAddonWithPluribusManager()
	if _G.PluribusAddonManager then
		_G.PluribusAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Inventory management",
			author = "Pluribus Suite Team",
			category = "Inventory",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "PluribusInventory" then
		if PluribusCore and PluribusDataManager then
			InitializeInventory()
		else
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if PluribusCore and PluribusDataManager then
						InitializeInventory()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


