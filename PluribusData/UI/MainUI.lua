-- PluribusData UI Module
-- Suite Data Vault, Registered Data Sources, Memory Telemetry & Garbage Collection

PluribusDataUI = {}
_G.PluribusDataUI = PluribusDataUI

function PluribusDataUI:Toggle()
	if not _G.PluribusDataWindow then
		_G.PluribusDataWindow = self:Create()
		_G.PluribusDataWindow:Show()
		return
	end
	if _G.PluribusDataWindow:IsVisible() then
		_G.PluribusDataWindow:Hide()
	else
		self:Refresh(_G.PluribusDataWindow)
		_G.PluribusDataWindow:Show()
	end
end

function PluribusDataUI:Create()
	local frame = PluribusUIFramework:CreateFrame(
		"PluribusDataWindow",
		UIParent,
		600,
		430,
		"Pluribus Data Vault",
		"SavedVariables & Registered Data Sources"
	)
	frame:SetPoint("CENTER")

	frame.body = CreateFrame("Frame", nil, frame)
	frame.body:SetSize(576, 376)
	frame.body:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)

	self:Refresh(frame)
	return frame
end

function PluribusDataUI:Refresh(frame)
	local b = frame.body
	PluribusUIFramework:ClearContainer(b)

	local sources = (_G.PluribusDataManager and _G.PluribusDataManager.sources) or {}
	local sourceCount = 0
	for _ in pairs(sources) do sourceCount = sourceCount + 1 end
	local memMB = ((collectgarbage and collectgarbage("count")) or 0) / 1024
	local addonCount = 0
	if _G.PluribusAddonManager and _G.PluribusAddonManager.addons then
		for _ in pairs(_G.PluribusAddonManager.addons) do addonCount = addonCount + 1 end
	end

	local m1 = PluribusUIFramework:CreateMetricTile(b, 184, 58, "Data Sources", sourceCount, "|cff38bdf8")
	m1:SetPoint("TOPLEFT", b, "TOPLEFT", 0, -2)
	local m2 = PluribusUIFramework:CreateMetricTile(b, 184, 58, "Active Addons", addonCount, "|cff4ade80")
	m2:SetPoint("LEFT", m1, "RIGHT", 12, 0)
	local m3 = PluribusUIFramework:CreateMetricTile(b, 184, 58, "Lua Heap", string.format("%.2f MB", memMB), "|cfffbbf24")
	m3:SetPoint("LEFT", m2, "RIGHT", 12, 0)

	local listCard = PluribusUIFramework:CreateCard(b, 576, 260, "Registered Data Vault Sources")
	listCard:SetPoint("TOPLEFT", m1, "BOTTOMLEFT", 0, -10)

	local scroll = PluribusUIFramework:CreateScrollFrame(listCard, "PluribusDataVaultScroll", 560, 220)
	scroll:SetPoint("TOPLEFT", listCard, "TOPLEFT", 8, -32)
	local content = scroll.content

	local y = -2
	local idx = 0
	for name, payload in pairs(sources) do
		idx = idx + 1
		local keys = 0
		if type(payload) == "table" then
			for _ in pairs(payload) do keys = keys + 1 end
		end
		local row = PluribusUIFramework:CreateListRow(content, 534, 24, idx)
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 2, y)
		local l = PluribusUIFramework:CreateLabel(row, "|cff38bdf8" .. tostring(name) .. "|r")
		l:SetPoint("LEFT", row, "LEFT", 8, 0)
		local r = PluribusUIFramework:CreateLabel(row, "|cff94a3b8" .. tostring(keys) .. " dataset buckets|r")
		r:SetPoint("RIGHT", row, "RIGHT", -8, 0)
		y = y - 26
	end
	if idx == 0 then
		local empty = PluribusUIFramework:CreateLabel(content, "|cff94a3b8No external data sources registered yet.|r")
		empty:SetPoint("TOPLEFT", content, "TOPLEFT", 8, -10)
	end
	content:SetHeight(math.max(210, -y + 10))

	local compactBtn = PluribusUIFramework:CreateButton(b, "Optimize Memory (GC)", 156, 26, function()
		collectgarbage("collect")
		PluribusDataUI:Refresh(frame)
		PluribusUIFramework:ShowNotification("Lua memory compacted.", 2.2)
	end, true)
	compactBtn:SetPoint("TOPLEFT", listCard, "BOTTOMLEFT", 0, -10)

	local refreshBtn = PluribusUIFramework:CreateButton(b, "Refresh", 90, 26, function()
		PluribusDataUI:Refresh(frame)
	end)
	refreshBtn:SetPoint("LEFT", compactBtn, "RIGHT", 8, 0)
end

return PluribusDataUI
