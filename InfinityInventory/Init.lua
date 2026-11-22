-- InfinityInventory Initialization

local function InitializeInventory()
	InfinityUtils:Info("InfinityInventory initializing...", "Inventory")
	
	if not InfinityCore or not InfinityDataManager then
		InfinityUtils:Warning("InfinityCore not ready", "Inventory")
		return
	end
	
	-- Initialize modules
	if InfinityBagTracker then pcall(function() InfinityBagTracker:Initialize() end) end
	if InfinityItemTracking then pcall(function() InfinityItemTracking:Initialize() end) end
	if InfinityCraftingIntegration then pcall(function() InfinityCraftingIntegration:Initialize() end) end
	if InfinityVendorPricing then pcall(function() InfinityVendorPricing:Initialize() end) end
	if InfinityInventoryUI then pcall(function() InfinityInventoryUI:Initialize() end) end
	
	-- Register globals
	_G.InfinityBagTracker = InfinityBagTracker
	_G.InfinityItemTracking = InfinityItemTracking
	_G.InfinityCraftingIntegration = InfinityCraftingIntegration
	_G.InfinityVendorPricing = InfinityVendorPricing
	_G.InfinityInventoryUI = InfinityInventoryUI
	
	-- Slash commands
	InfinityCommandRegistry:RegisterCommand("inv", function(args)
		if not args or #args == 0 then
			InfinityInventoryUI:Toggle()
		elseif args[1] == "scan" then
			InfinityBagTracker:ScanBags()
			InfinityUtils:Info("Bags scanned", "Inventory")
		elseif args[1] == "value" then
			local value = InfinityVendorPricing:CalculateBagValue()
			InfinityUtils:Info("Total bag value: " .. InfinityUtils:FormatGold(value), "Inventory")
		elseif args[1] == "free" then
			local free = InfinityBagTracker:GetFreeSlots()
			InfinityUtils:Info("Free slots: " .. free, "Inventory")
		elseif args[1] == "item" and args[2] then
			local count = InfinityBagTracker:GetItemCount(tonumber(args[2]))
			InfinityUtils:Info("Item count: " .. count, "Inventory")
		end
	end, {"inventory"})
	
	InfinityUtils:Info("InfinityInventory initialized successfully", "Inventory")
	InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, "inventory", true)
end


local function RegisterAddonWithInfinityManager()
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon(ADDON_NAME, ADDON_VERSION, {
			description = "Inventory management",
			author = "Infinity Suite Team",
			category = "Inventory",
			enabled = true,
			settings = {{}}
		})
	end
end

	local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, addonName)
	if addonName == "InfinityInventory" then
		if InfinityCore and InfinityDataManager then
			InitializeInventory()
		else
			local retry = 0
			local retryFrame = CreateFrame("Frame")
			retryFrame:SetScript("OnUpdate", function(f, elapsed)
				retry = retry + elapsed
				if retry > 0.5 then
					if InfinityCore and InfinityDataManager then
						InitializeInventory()
						f:Hide()
					end
				end
			end)
		end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)


