-- InfinityQoL UI & Live Automation Module
-- Real Quality-of-Life toggles wired directly to WoW Merchant, Party, Resurrection & Loot events

InfinityQoLUI = {
	config = {
		autoRepair = true,
		autoSellGray = true,
		autoAcceptGuildInvite = true,
		autoAcceptResurrect = false,
		autoReleaseBG = true,
		fastLoot = true,
	},
}
_G.InfinityQoLUI = InfinityQoLUI

-- Real in-game automation event handler
local qolEvents = CreateFrame("Frame")
qolEvents:RegisterEvent("MERCHANT_SHOW")
qolEvents:RegisterEvent("PARTY_INVITE_REQUEST")
qolEvents:RegisterEvent("RESURRECT_REQUEST")
qolEvents:RegisterEvent("LOOT_READY")
qolEvents:SetScript("OnEvent", function(_, event, arg1)
	local cfg = InfinityQoLUI.config
	if event == "MERCHANT_SHOW" then
		if cfg.autoRepair and CanMerchantRepair and CanMerchantRepair() then
			local cost, canRepair = GetRepairAllCost()
			if canRepair and cost and cost > 0 then
				if CanGuildBankRepair and CanGuildBankRepair() then
					RepairAllItems(true)
				else
					RepairAllItems(false)
				end
				if InfinityUIFramework then
					InfinityUIFramework:ShowNotification("Auto-repaired gear (" .. ((InfinityUtils and InfinityUtils:FormatGold(cost)) or tostring(cost)) .. ").", 2.5)
				end
			end
		end
		if cfg.autoSellGray and _G.InfinityInventoryUI and _G.InfinityInventoryUI.SellGrayJunk then
			_G.InfinityInventoryUI:SellGrayJunk()
		end
	elseif event == "PARTY_INVITE_REQUEST" and cfg.autoAcceptGuildInvite then
		if IsInGuild and IsInGuild() and AcceptGroup then
			for i = 1, (GetNumGuildMembers and GetNumGuildMembers() or 0) do
				local gName = GetGuildRosterInfo(i)
				if gName and arg1 and gName:match("^[^-]+") == arg1:match("^[^-]+") then
					AcceptGroup()
					if StaticPopup_Hide then StaticPopup_Hide("PARTY_INVITE") end
					break
				end
			end
		end
	elseif event == "RESURRECT_REQUEST" and cfg.autoAcceptResurrect then
		if AcceptResurrect and not (UnitAffectingCombat and UnitAffectingCombat("player")) then
			AcceptResurrect()
		end
	elseif event == "LOOT_READY" and cfg.fastLoot and GetNumLootItems and LootSlot then
		if GetCVarBool and GetCVarBool("autoLootDefault") then
			for i = GetNumLootItems(), 1, -1 do
				pcall(LootSlot, i)
			end
		end
	end
end)

function InfinityQoLUI:Save()
	if InfinityStorageManager and InfinityStorageManager.SetAddonSetting then
		InfinityStorageManager:SetAddonSetting("InfinityQoL", "config", self.config)
	end
end

function InfinityQoLUI:Toggle()
	if not _G.InfinityQoLWindow then
		_G.InfinityQoLWindow = self:Create()
		_G.InfinityQoLWindow:Show()
		return
	end
	_G.InfinityQoLWindow:SetShown(not _G.InfinityQoLWindow:IsShown())
end

function InfinityQoLUI:Create()
	local frame = InfinityUIFramework:CreateFrame(
		"InfinityQoLWindow",
		UIParent,
		560,
		410,
		"Infinity QoL Automation",
		"Vendor, Loot & Raid Conveniences"
	)
	frame:SetPoint("CENTER")

	local card = InfinityUIFramework:CreateCard(frame, 536, 310, "Active Quality-of-Life Automations")
	card:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -46)

	local options = {
		{ key = "autoRepair", label = "Auto-Repair All Gear at Vendors (Uses Guild Bank first when allowed)" },
		{ key = "autoSellGray", label = "Auto-Sell Poor (Gray) Junk Items on Merchant Open" },
		{ key = "autoAcceptGuildInvite", label = "Auto-Accept Raid / Party Invites from Guildmates" },
		{ key = "autoAcceptResurrect", label = "Auto-Accept Out-of-Combat Resurrection Requests" },
		{ key = "fastLoot", label = "Fast Auto-Loot Acceleration (Instant LootSlot Sweep)" },
		{ key = "autoReleaseBG", label = "Auto-Release Spirit inside Battlegrounds" },
	}

	local y = -34
	for _, opt in ipairs(options) do
		local cb = InfinityUIFramework:CreateCheckbox(card, opt.label, self.config[opt.key], function(checked)
			InfinityQoLUI.config[opt.key] = checked
			InfinityQoLUI:Save()
		end)
		cb:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
		y = y - 40
	end

	local reloadBtn = InfinityUIFramework:CreateButton(frame, "Reload UI (/reload)", 140, 26, function()
		if ReloadUI then ReloadUI() end
	end)
	reloadBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)

	local gcBtn = InfinityUIFramework:CreateButton(frame, "Collect Lua Garbage", 150, 26, function()
		local before = collectgarbage("count")
		collectgarbage("collect")
		local after = collectgarbage("count")
		InfinityUIFramework:ShowNotification(string.format("Freed %.1f KB Lua memory.", math.max(0, before - after)), 2.5)
	end, true)
	gcBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 10, 0)

	return frame
end

return InfinityQoLUI
