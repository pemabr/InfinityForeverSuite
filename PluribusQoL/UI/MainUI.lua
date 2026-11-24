-- PluribusQoL UI & Live Automation Module
-- Real Quality-of-Life toggles wired directly to WoW Merchant, Party, Resurrection & Loot events

PluribusQoLUI = {
	config = {
		autoRepair = true,
		autoSellGray = true,
		autoAcceptGuildInvite = true,
		autoAcceptResurrect = false,
		autoReleaseBG = true,
		fastLoot = true,
	},
}
_G.PluribusQoLUI = PluribusQoLUI

-- Real in-game automation event handler
local qolEvents = CreateFrame("Frame")
qolEvents:RegisterEvent("MERCHANT_SHOW")
qolEvents:RegisterEvent("PARTY_INVITE_REQUEST")
qolEvents:RegisterEvent("RESURRECT_REQUEST")
qolEvents:RegisterEvent("LOOT_READY")
qolEvents:SetScript("OnEvent", function(_, event, arg1)
	local cfg = PluribusQoLUI.config
	if event == "MERCHANT_SHOW" then
		if cfg.autoRepair and CanMerchantRepair and CanMerchantRepair() then
			local cost, canRepair = GetRepairAllCost()
			if canRepair and cost and cost > 0 then
				if CanGuildBankRepair and CanGuildBankRepair() then
					RepairAllItems(true)
				else
					RepairAllItems(false)
				end
				if PluribusUIFramework then
					PluribusUIFramework:ShowNotification("Auto-repaired gear (" .. ((PluribusUtils and PluribusUtils:FormatGold(cost)) or tostring(cost)) .. ").", 2.5)
				end
			end
		end
		if cfg.autoSellGray and _G.PluribusInventoryUI and _G.PluribusInventoryUI.SellGrayJunk then
			_G.PluribusInventoryUI:SellGrayJunk()
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

function PluribusQoLUI:Save()
	if PluribusStorageManager and PluribusStorageManager.SetAddonSetting then
		PluribusStorageManager:SetAddonSetting("PluribusQoL", "config", self.config)
	end
end

function PluribusQoLUI:Toggle()
	if not _G.PluribusQoLWindow then
		_G.PluribusQoLWindow = self:Create()
		_G.PluribusQoLWindow:Show()
		return
	end
	_G.PluribusQoLWindow:SetShown(not _G.PluribusQoLWindow:IsShown())
end

function PluribusQoLUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusQoLWindow",
		UIParent,
		560,
		410,
		"Pluribus QoL Automation",
		"Vendor, Loot & Raid Conveniences"
	)
	frame:SetPoint("CENTER")

	local card = PluribusUIFramework:CreateCard(frame, 536, 310, "Active Quality-of-Life Automations")
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
		local cb = PluribusUIFramework:CreateCheckbox(card, opt.label, self.config[opt.key], function(checked)
			PluribusQoLUI.config[opt.key] = checked
			PluribusQoLUI:Save()
		end)
		cb:SetPoint("TOPLEFT", card, "TOPLEFT", 12, y)
		y = y - 40
	end

	local reloadBtn = PluribusUIFramework:CreateButton(frame, "Reload UI (/reload)", 140, 26, function()
		if ReloadUI then ReloadUI() end
	end)
	reloadBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 14)

	local gcBtn = PluribusUIFramework:CreateButton(frame, "Collect Lua Garbage", 150, 26, function()
		local before = collectgarbage("count")
		collectgarbage("collect")
		local after = collectgarbage("count")
		PluribusUIFramework:ShowNotification(string.format("Freed %.1f KB Lua memory.", math.max(0, before - after)), 2.5)
	end, true)
	gcBtn:SetPoint("LEFT", reloadBtn, "RIGHT", 10, 0)

	return frame
end

return PluribusQoLUI
