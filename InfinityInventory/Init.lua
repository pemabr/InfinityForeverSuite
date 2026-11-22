-- InfinityInventory Initialization

local function InitializeInventory()
	InfinityUtils:Info("InfinityInventory initializing...", "Inventory")
	
	if not InfinityCore or not InfinityDataManager then
		InfinityUtils:Warning("InfinityCore not ready", "Inventory")
		return
	end
	
	-- Initialize modules
	if not InfinityBagTracker or not InfinityItemTracking or not InfinityCraftingIntegration
		or not InfinityVendorPricing or not InfinityInventoryUI or not InfinityUIFramework
		or not InfinityAuctionPrices or not InfinityShoppingLists then
		InfinityUtils:Error("Inventory modules unavailable.", "Inventory")
		return
	end
	InfinityBagTracker:Initialize()
	InfinityItemTracking:Initialize()
	InfinityCraftingIntegration:Initialize()
	InfinityVendorPricing:Initialize()
	InfinityInventoryUI:Initialize()
	InfinityAuctionPrices:Initialize()
	InfinityShoppingLists:Initialize()
	
	-- Register globals
	_G.InfinityBagTracker = InfinityBagTracker
	_G.InfinityItemTracking = InfinityItemTracking
	_G.InfinityCraftingIntegration = InfinityCraftingIntegration
	_G.InfinityVendorPricing = InfinityVendorPricing
	_G.InfinityInventoryUI = InfinityInventoryUI
	
	local function ScanForCommand()
		if InfinityBagTracker:ScanBags() then return true end
		print("Inventory: " .. InfinityBagTracker.scanError)
		return false
	end

	-- Slash commands
	InfinityCommandRegistry:RegisterCommand("inv", function(args)
		if not args or #args == 0 then
			InfinityInventoryUI:Toggle()
		elseif args[1] == "scan" then
			if ScanForCommand() then
				InfinityUtils:Info("Bags scanned", "Inventory")
				if InfinityInventoryUI.mainFrame and InfinityInventoryUI.mainFrame:IsShown() then InfinityInventoryUI:Refresh() end
			end
		elseif args[1] == "value" then
			if ScanForCommand() then
				local value, missing = InfinityVendorPricing:CalculateVendorValue()
				local note = missing > 0 and ("; " .. missing .. " prices unavailable") or ""
				InfinityUtils:Info("Bag vendor value: " .. InfinityUtils:FormatGold(value) .. note, "Inventory")
			end
		elseif args[1] == "free" then
			if ScanForCommand() then
				InfinityUtils:Info("Free bag slots: " .. InfinityBagTracker:GetFreeSlots(), "Inventory")
			end
		elseif args[1] == "item" and args[2] then
			local itemId = tonumber(args[2])
			if not itemId or itemId <= 0 or itemId >= math.huge or itemId ~= math.floor(itemId) then
				InfinityUtils:Warning("Usage: /inv item <item ID>", "Inventory")
			elseif ScanForCommand() then
				InfinityUtils:Info("Bag item count: " .. InfinityBagTracker:GetItemCount(itemId), "Inventory")
			end
		elseif args[1] == "list" then
			local lists, action = InfinityShoppingLists, args[2]
			if not action then lists:Toggle()
			elseif action == "create" and args[3] then lists:Save(table.concat(args, " ", 3), {}, true)
			elseif action == "use" and args[3] and not args[4] then lists:Select(args[3])
			elseif action == "set" and args[3] and args[4] and not args[5] then lists:SetItem(tonumber(args[3]), tonumber(args[4]))
			elseif action == "remove" and args[3] and not args[4] then lists:RemoveItem(tonumber(args[3]))
			elseif action == "delete" and args[3] and not args[4] then lists:Delete(args[3])
			elseif action == "share" and not args[4] then lists:Share(args[3] or lists.active)
			else InfinityUtils:Warning("Usage: /inv list [create <name>|use <id|none>|set <item ID> <quantity>|remove <item ID>|delete <id>|share [id]]", "Inventory") end
		elseif args[1] == "price" and not args[3] then
			if args[2] then
				local itemID = tonumber(args[2])
				InfinityAuctionPrices:OpenItem(itemID)
			else
				InfinityAuctionPrices:Toggle()
			end
		elseif args[1] == "crafters" and not args[2] then
			if _G.InfinityGuildRecipes then InfinityGuildRecipes:Toggle()
			else InfinityUtils:Warning("Guild recipe reports require InfinityDataCollector.", "Inventory") end
		elseif args[1] == "stock" and not args[3] then
			if _G.InfinityGuildBagReports then
				if args[2] then InfinityGuildBagReports:OpenItem(tonumber(args[2]))
				else InfinityGuildBagReports:Toggle() end
			else InfinityUtils:Warning("Guild bag reports require InfinityDataCollector.", "Inventory") end
		elseif args[1] == "recipe" then
			local recipeId, crafts = tonumber(args[2]), 1
			if args[3] then crafts = tonumber(args[3]) end
			if not recipeId or not crafts or args[4] then
				print("Usage: /inv recipe <recipe ID> [quantity]")
			elseif ScanForCommand() then
				local materials, problem = InfinityCraftingIntegration:GetBasicMaterials(recipeId, crafts)
				if not materials then
					InfinityUtils:Warning(problem, "Inventory")
				else
					print("Basic reagents in bags only; bank, optional ingredients and other requirements are not checked.")
					if #materials == 0 then print("No basic reagents found; check the profession window.") end
					for _, item in ipairs(materials) do
						print(string.format("Item %d: %d / %d, missing %d", item.itemId, item.have, item.needed, item.missing))
					end
				end
			end
		else
			InfinityUtils:Info("Usage: /inv [scan|value|free|item <item ID>|price [item ID]|list|crafters|stock [item ID]|recipe <recipe ID> [quantity]]", "Inventory")
		end
	end, {"inventory"})
	
	if _G.InfinityAddonManager then
		_G.InfinityAddonManager:RegisterAddon("InfinityInventory", "1.2.0", {
			description = "Inventory management",
			author = "Infinity Suite Team",
			category = "Inventory",
			enabled = true,
			settings = {}
		})
	end
	
	InfinityUtils:Info("InfinityInventory initialized successfully", "Inventory")
	InfinityMessaging:Publish(INFINITY_EVENTS.FEATURE_ENABLED, "inventory", true)
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


