-- PluribusHealer UI Module
-- Complete Click-Casting Studio, Raid Frame Configurator, HoT/Debuff Controls, and Live Interactive Preview

local PluribusHealerUI = {
	mainWindow = nil,
	currentTab = "clickcast",
	config = {
		frameWidth = 110,
		frameHeight = 42,
		columns = 5,
		showIncomingHeals = true,
		highlightDebuffs = true,
		fadeOutOfRange = true,
		showHoTTimers = true,
		bindings = {
			["Left-Click"] = "Flash Heal",
			["Right-Click"] = "Greater Heal",
			["Shift+Left"] = "Renew",
			["Ctrl+Left"] = "Dispel Magic",
			["Alt+Left"] = "Power Word: Shield",
		},
	},
	previewUnits = {
		{ name = "Kaelen", class = "WARRIOR", hp = 68, maxHp = 100, debuff = "Magic" },
		{ name = "Vaelor", class = "WARRIOR", hp = 84, maxHp = 100, debuff = nil },
		{ name = "Seraphina", class = "PRIEST", hp = 92, maxHp = 100, debuff = nil },
		{ name = "Sylvara", class = "MAGE", hp = 54, maxHp = 100, debuff = "Curse" },
		{ name = "Thorn", class = "DRUID", hp = 79, maxHp = 100, debuff = "Poison" },
		{ name = "Ragnar", class = "ROGUE", hp = 46, maxHp = 100, debuff = nil },
		{ name = "Lyra", class = "HUNTER", hp = 96, maxHp = 100, debuff = nil },
		{ name = "Mordecai", class = "WARLOCK", hp = 61, maxHp = 100, debuff = "Magic" },
	},
}
_G.PluribusHealerUI = PluribusHealerUI

function PluribusHealerUI:Initialize()
	if PluribusStorageManager and PluribusStorageManager.GetAddonSetting then
		local saved = PluribusStorageManager:GetAddonSetting("PluribusHealer", "uiConfig")
		if type(saved) == "table" then
			for k, v in pairs(saved) do self.config[k] = v end
		end
	end
	if PluribusUtils and PluribusUtils.Info then
		PluribusUtils:Info("Healer UI initialized", "Healer")
	end
end

function PluribusHealerUI:SaveConfig()
	if PluribusStorageManager and PluribusStorageManager.SetAddonSetting then
		PluribusStorageManager:SetAddonSetting("PluribusHealer", "uiConfig", self.config)
	end
	if _G.PluribusClickCast and _G.PluribusClickCast.BindSpell then
		for combo, spell in pairs(self.config.bindings) do
			pcall(function() _G.PluribusClickCast:BindSpell(combo, spell) end)
		end
	end
end

function PluribusHealerUI:Toggle()
	if not self.mainWindow then
		self:CreateMainWindow()
	end
	if self.mainWindow:IsShown() then
		self.mainWindow:Hide()
	else
		self:ShowTab(self.currentTab or "clickcast")
		self.mainWindow:Show()
	end
end

function PluribusHealerUI:CreateMainWindow()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusHealerMainWindow",
		UIParent,
		720,
		490,
		"Pluribus Healer Studio",
		"Click-Casting, Frames & Live Preview"
	)
	frame:SetPoint("CENTER")

	local tabs = {
		{ name = "Click-Casting", key = "clickcast" },
		{ name = "Frame Layout", key = "layout" },
		{ name = "HoTs & Debuffs", key = "auras" },
		{ name = "Live Preview", key = "preview" },
	}

	local tabBar = PluribusUIFramework:CreateTabBar(frame, tabs, function(key)
		PluribusHealerUI.currentTab = key
		PluribusHealerUI:ShowTab(key)
	end, 696)
	tabBar:SetPoint("TOP", frame, "TOP", 0, -44)
	frame.tabBar = tabBar

	frame.content = CreateFrame("Frame", nil, frame)
	frame.content:SetSize(696, 396)
	frame.content:SetPoint("TOP", tabBar, "BOTTOM", 0, -8)

	self.mainWindow = frame
	tabBar:SelectTab("clickcast")
end

function PluribusHealerUI:ShowTab(tabKey)
	if not self.mainWindow or not self.mainWindow.content then return end
	local c = self.mainWindow.content
	PluribusUIFramework:ClearContainer(c)

	if tabKey == "clickcast" then
		local card = PluribusUIFramework:CreateCard(c, 696, 336, "Click-Cast Spell Bindings (Applied to Healer Frames)")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

		local combos = { "Left-Click", "Right-Click", "Shift+Left", "Ctrl+Left", "Alt+Left" }
		local inputs = {}
		local y = -36
		for _, combo in ipairs(combos) do
			local lbl = PluribusUIFramework:CreateLabel(card, "|cff38bdf8" .. combo .. "|r")
			lbl:SetPoint("TOPLEFT", card, "TOPLEFT", 16, y)

			local box = PluribusUIFramework:CreateInputBox(card, 240, 24)
			box:SetPoint("TOPLEFT", card, "TOPLEFT", 130, y + 4)
			box:SetText(self.config.bindings[combo] or "")
			inputs[combo] = box

			local testBtn = PluribusUIFramework:CreateButton(card, "Test Bind", 86, 24, function()
				local sp = box:GetText()
				PluribusHealerUI.config.bindings[combo] = sp
				PluribusHealerUI:SaveConfig()
				PluribusUIFramework:ShowNotification("Bound " .. combo .. " -> " .. sp, 2.2)
			end)
			testBtn:SetPoint("LEFT", box, "RIGHT", 10, 0)

			y = y - 44
		end

		local saveBtn = PluribusUIFramework:CreateButton(c, "Save All Click-Cast Bindings", 190, 28, function()
			for combo, box in pairs(inputs) do
				PluribusHealerUI.config.bindings[combo] = box:GetText()
			end
			PluribusHealerUI:SaveConfig()
			PluribusUIFramework:ShowNotification("|cff4ade80Healer click-cast bindings saved.|r", 2.5)
		end, true)
		saveBtn:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -12)

	elseif tabKey == "layout" then
		local card = PluribusUIFramework:CreateCard(c, 696, 336, "Raid Frame Geometry & Behavior")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

		local wLbl = PluribusUIFramework:CreateLabel(card, "Unit Frame Width: |cfffbbf24" .. tostring(self.config.frameWidth) .. "px|r")
		wLbl:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -38)
		local wMinus = PluribusUIFramework:CreateButton(card, "-10", 44, 22, function()
			self.config.frameWidth = math.max(70, self.config.frameWidth - 10)
			self:SaveConfig()
			self:ShowTab("layout")
		end)
		wMinus:SetPoint("LEFT", wLbl, "RIGHT", 16, 0)
		local wPlus = PluribusUIFramework:CreateButton(card, "+10", 44, 22, function()
			self.config.frameWidth = math.min(180, self.config.frameWidth + 10)
			self:SaveConfig()
			self:ShowTab("layout")
		end)
		wPlus:SetPoint("LEFT", wMinus, "RIGHT", 6, 0)

		local hLbl = PluribusUIFramework:CreateLabel(card, "Unit Frame Height: |cfffbbf24" .. tostring(self.config.frameHeight) .. "px|r")
		hLbl:SetPoint("TOPLEFT", wLbl, "BOTTOMLEFT", 0, -24)
		local hMinus = PluribusUIFramework:CreateButton(card, "-4", 44, 22, function()
			self.config.frameHeight = math.max(24, self.config.frameHeight - 4)
			self:SaveConfig()
			self:ShowTab("layout")
		end)
		hMinus:SetPoint("LEFT", hLbl, "RIGHT", 16, 0)
		local hPlus = PluribusUIFramework:CreateButton(card, "+4", 44, 22, function()
			self.config.frameHeight = math.min(80, self.config.frameHeight + 4)
			self:SaveConfig()
			self:ShowTab("layout")
		end)
		hPlus:SetPoint("LEFT", hMinus, "RIGHT", 6, 0)

		local cbHeal = PluribusUIFramework:CreateCheckbox(card, "Show Incoming Heal Prediction Overlay", self.config.showIncomingHeals, function(v)
			self.config.showIncomingHeals = v
			self:SaveConfig()
		end)
		cbHeal:SetPoint("TOPLEFT", hLbl, "BOTTOMLEFT", -4, -28)

		local cbRange = PluribusUIFramework:CreateCheckbox(card, "Fade Out-of-Range Units (40yd Range Checker)", self.config.fadeOutOfRange, function(v)
			self.config.fadeOutOfRange = v
			self:SaveConfig()
		end)
		cbRange:SetPoint("TOPLEFT", cbHeal, "BOTTOMLEFT", 0, -8)

	elseif tabKey == "auras" then
		local card = PluribusUIFramework:CreateCard(c, 696, 336, "HoT Timers & Dispellable Debuff Highlights")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

		local cbHot = PluribusUIFramework:CreateCheckbox(card, "Track Active HoT Durations (Renew, Rejuvenation, Regrowth)", self.config.showHoTTimers, function(v)
			self.config.showHoTTimers = v
			self:SaveConfig()
		end)
		cbHot:SetPoint("TOPLEFT", card, "TOPLEFT", 14, -36)

		local cbDebuff = PluribusUIFramework:CreateCheckbox(card, "Highlight Dispellable Magic / Curse / Poison / Disease Borders", self.config.highlightDebuffs, function(v)
			self.config.highlightDebuffs = v
			self:SaveConfig()
		end)
		cbDebuff:SetPoint("TOPLEFT", cbHot, "BOTTOMLEFT", 0, -10)

		local info = PluribusUIFramework:CreateLabel(card, "|cff94a3b8Color Key:|r  |cff38bdf8Magic (Blue)|r   |cffa855f7Curse (Purple)|r   |cff4ade80Poison (Green)|r   |cfffbbf24Disease (Gold)|r")
		info:SetPoint("TOPLEFT", cbDebuff, "BOTTOMLEFT", 4, -24)

	elseif tabKey == "preview" then
		local card = PluribusUIFramework:CreateCard(c, 696, 336, "Interactive Raid Grid Preview (Left-Click to Heal, Ctrl+Click to Dispel)")
		card:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)

		local cols = 4
		for i, u in ipairs(self.previewUnits) do
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)
			local cr, cg, cb, cHex = PluribusUIFramework:GetClassColor(u.class)
			local bar = PluribusUIFramework:CreateStatusBar(card, 158, 42, cr, cg, cb)
			bar:SetPoint("TOPLEFT", card, "TOPLEFT", 14 + col * 168, -42 - row * 56)

			local debuffTag = u.debuff and (" |cfff87171[" .. u.debuff .. "]|r") or ""
			bar:SetBarData(u.hp, cHex .. u.name .. "|r" .. debuffTag, tostring(u.hp) .. "%")

			bar:SetScript("OnClick", function()
				if IsControlKeyDown and IsControlKeyDown() then
					u.debuff = nil
					PluribusUIFramework:ShowNotification("Dispelled " .. u.name .. " (" .. (self.config.bindings["Ctrl+Left"] or "Dispel") .. ")", 2)
				else
					u.hp = math.min(100, u.hp + 22)
					PluribusUIFramework:ShowNotification("Cast " .. (self.config.bindings["Left-Click"] or "Flash Heal") .. " on " .. u.name, 2)
				end
				PluribusHealerUI:ShowTab("preview")
			end)
		end

		local simDmgBtn = PluribusUIFramework:CreateButton(c, "Simulate Raid Damage", 160, 26, function()
			for _, u in ipairs(self.previewUnits) do
				u.hp = math.max(18, u.hp - math.random(12, 34))
			end
			self:ShowTab("preview")
		end)
		simDmgBtn:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 0, -12)
	end
end

return PluribusHealerUI
