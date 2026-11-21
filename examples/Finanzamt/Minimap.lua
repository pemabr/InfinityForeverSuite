-- Finanzamt – Minimap-Button (ohne Bibliotheken)
-- Linksklick: Fenster öffnen/schließen · Rechtsklick: Offiziersliste · Ziehen: verschieben
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF

local button
local atan2 = math.atan2 or math.atan

local function settings()
	GS.db.minimap = GS.db.minimap or { angle = 200, hide = false }
	return GS.db.minimap
end

local function updatePosition()
	if not button then return end
	local a = math.rad(settings().angle or 200)
	local r = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function onDragUpdate()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	settings().angle = math.deg(atan2(py - my, px - mx)) % 360
	updatePosition()
end

local function updateAlert()
	if not button or not GS:G() then return end
	local a = GS:AccountFor(GS.player)
	if a and a.status == "überfällig" then
		button.alert:SetVertexColor(1, 0.2, 0.2)
		button.alert:Show()
	elseif a and a.status == "offen" then
		button.alert:SetVertexColor(1, 0.8, 0.1)
		button.alert:Show()
	else
		button.alert:Hide()
	end
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Finanzamt " .. GS.VERSION)
	local a = GS:G() and GS:AccountFor(GS.player)
	if a then
		GameTooltip:AddDoubleLine(L["Saldo:"], GS:FormatMoney(a.bal), 1, 0.82, 0, 1, 1, 1)
		GameTooltip:AddDoubleLine(L["Status:"], GS:ColorStatus(a.status), 1, 0.82, 0, 1, 1, 1)
		GameTooltip:AddDoubleLine(L["Laufende Woche (gesch.):"], GS:FormatMoney(a.cur.total), 1, 0.82, 0, 1, 1, 1)
		if GS:HasRight(GS.player, "officer") then
			local missing = 0
			for name, r in pairs(GS.roster) do
				if r.online and GS:MemberStatus(name) == "online ohne Addon" then missing = missing + 1 end
			end
			if missing > 0 then
				GameTooltip:AddDoubleLine(L["Online ohne Addon:"], "|cffff4040" .. missing .. "|r", 1, 0.82, 0)
			end
		end
	else
		GameTooltip:AddLine(L["Keine Gildendaten."], 0.7, 0.7, 0.7)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["|cffffffffLinksklick:|r Fenster öffnen"], 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L["|cffffffffRechtsklick:|r Offiziersliste"], 0.8, 0.8, 0.8)
	GameTooltip:AddLine(L["|cffffffffZiehen:|r verschieben"], 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

local function create()
	if button or not Minimap then return end
	local b = CreateFrame("Button", "FinanzamtMinimapButton", Minimap)
	b:SetSize(31, 31)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetPoint("TOPLEFT", 7, -5)

	local icon = b:CreateTexture(nil, "ARTWORK")
	icon:SetSize(18, 18)
	icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_01")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	icon:SetPoint("TOPLEFT", 7, -6)
	b.icon = icon

	local border = b:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	-- kleiner Punkt bei offener/überfälliger Steuer
	local alert = b:CreateTexture(nil, "OVERLAY", nil, 7)
	alert:SetSize(10, 10)
	alert:SetTexture("Interface\\COMMON\\Indicator-Gray")
	alert:SetPoint("TOPRIGHT", -2, -2)
	alert:Hide()
	b.alert = alert

	b:SetScript("OnClick", function(_, btn)
		if btn == "RightButton" then
			GS.UI:ShowTab("offi")
		else
			GS.UI:Toggle()
		end
	end)
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", onDragUpdate)
		GameTooltip:Hide()
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnEnter", showTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)

	button = b
	GS.minimapButton = b
	updatePosition()
	if settings().hide then b:Hide() end
	updateAlert()
end

function GS:ToggleMinimapButton()
	local s = settings()
	s.hide = not s.hide
	if not button then create() end
	if button then
		if s.hide then button:Hide() else button:Show() end
	end
	self:Print(s.hide and L["Minimap-Button ausgeblendet (/gst minimap zum Einblenden)"] or L["Minimap-Button eingeblendet"])
end

GS:On("PLAYER_LOGIN", function() create() end)
GS:Register("DATA_CHANGED", function() GS:Debounce("minimap", 2, updateAlert) end)
GS:Register("GUILD_READY", function() C_Timer.After(5, updateAlert) end)
