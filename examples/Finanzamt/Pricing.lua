-- Finanzamt – Item-Bewertung: Auctionator, eigener AH-Scan, Händlerpreis
local GS = select(2, ...).GS
local L, LF = GS.L, GS.LF
local floor = math.floor

function GS:AuctionatorPrice(id)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if api and api.GetAuctionPriceByItemID then
		local ok, p = pcall(api.GetAuctionPriceByItemID, "Finanzamt", id)
		if ok and type(p) == "number" and p > 0 then return p end
	end
end

function GS:ScanPrice(id, maxAgeDays)
	local g = self:G()
	local e = g and g.prices[id]
	if e and e.p and e.p > 0 and (self:Now() - (e.t or 0)) <= (maxAgeDays or 7) * 86400 then
		return e.p
	end
end

function GS:VendorPrice(id)
	local sp = select(11, GS.GetItemInfo(id))
	if sp and sp > 0 then return sp end
end

-- Stückpreis + Quelle ("auc", "scan", "vendor", "none")
function GS:GetUnitPrice(id)
	local B = self:GetEffective("bank", self:CurrentWeek())
	local src = B.source or "auctionator"
	if src == "auctionator" then
		local p = self:AuctionatorPrice(id)
		if p then return p, "auc" end
	end
	if src ~= "vendor" then
		local p = self:ScanPrice(id, B.maxAge)
		if p then return p, "scan" end
	end
	local p = self:VendorPrice(id)
	if p then return p, "vendor" end
	return 0, "none"
end

GS.SOURCE_LABEL = {
	auc = "Auctionator",
	scan = "AH-Scan",
	vendor = "Händler (ungeprüft)",
	none = "kein Preis (ungeprüft)",
	manual = "festgesetzt",
	gold = "Gold",
}

function GS:IsUnverified(src)
	return src == "vendor" or src == "none"
end

---------------------------------------------------------------------------
-- Eigener AH-Komplettscan
---------------------------------------------------------------------------
local function ahShown() GS.ahOpen = true end
local function ahHidden()
	GS.ahOpen = false
	GS.scanning = false
end
GS:On("AUCTION_HOUSE_SHOW", ahShown)
GS:On("AUCTION_HOUSE_CLOSED", ahHidden)
local function isAuctioneer(t)
	return Enum and Enum.PlayerInteractionType and t == Enum.PlayerInteractionType.Auctioneer
end
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", function(t) if isAuctioneer(t) then ahShown() end end)
GS:On("PLAYER_INTERACTION_MANAGER_FRAME_HIDE", function(t) if isAuctioneer(t) then ahHidden() end end)

local SCAN_COOLDOWN = 15 * 60

-- Neue Auktionshaus-API (C_AuctionHouse.ReplicateItems) oder klassische (QueryAuctionItems getAll)
function GS:ScanMode()
	if C_AuctionHouse and C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetReplicateItemInfo then return "replicate" end
	if QueryAuctionItems and CanSendAuctionQuery and GetAuctionItemInfo then return "classic" end
	return nil
end

function GS:StartScan()
	if not self:G() then return false, L["Keine Gilde"] end
	if not self.ahOpen then return false, L["Das Auktionshaus ist nicht geöffnet."] end
	local mode = self:ScanMode()
	if not mode then return false, L["Dieser Client bietet keine Scan-Funktion an – Preise kommen dann aus Auctionator."] end
	local last = self.db.lastScan or 0
	local wait = SCAN_COOLDOWN - (self:Now() - last)
	if mode == "classic" then
		local _, canAll = CanSendAuctionQuery()
		if not canAll then
			return false, L["Komplettscan gerade nicht möglich (nur alle 15 Minuten)."]
		end
	elseif wait > 0 then
		return false, LF("Komplettscan erst in %d Min. wieder möglich (Server-Sperre 15 Minuten).", math.ceil(wait / 60))
	end
	self.scanning = mode
	self.db.lastScan = self:Now()
	if mode == "replicate" then
		C_AuctionHouse.ReplicateItems()
	else
		QueryAuctionItems("", nil, nil, 0, false, -1, true, false, nil)
	end
	return true
end

local function savePrices(prices, n)
	local g = GS:G()
	if not g then return end
	local now, cnt = GS:Now(), 0
	for id, p in pairs(prices) do
		g.prices[id] = { p = p, t = now }
		cnt = cnt + 1
	end
	if n == 0 then
		GS:Print(L["AH-Scan lieferte keine Auktionen – evtl. sperrt der Server den Scan noch. Später erneut versuchen."])
	else
		GS:Print(LF("AH-Scan fertig: %d Auktionen, %d Preise gespeichert.", n, cnt))
	end
	GS:Fire("DATA_CHANGED")
end

local function addPrice(prices, itemId, buyout, count)
	if itemId and buyout and buyout > 0 and count and count > 0 then
		local unit = floor(buyout / count)
		if not prices[itemId] or unit < prices[itemId] then prices[itemId] = unit end
	end
end

local function processClassic()
	if GS.scanning ~= "classic" then return end
	GS.scanning = false
	local n = GetNumAuctionItems("list") or 0
	local prices = {}
	for i = 1, n do
		local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemId = GetAuctionItemInfo("list", i)
		addPrice(prices, itemId, buyout, count)
	end
	savePrices(prices, n)
end

local function processReplicate()
	if GS.scanning ~= "replicate" then return end
	GS.scanning = false
	local n = (C_AuctionHouse.GetNumReplicateItems and C_AuctionHouse.GetNumReplicateItems()) or 0
	local prices = {}
	-- Indizes beginnen bei 0
	for i = 0, n - 1 do
		local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemId = C_AuctionHouse.GetReplicateItemInfo(i)
		addPrice(prices, itemId, buyout, count)
	end
	savePrices(prices, n)
end

GS:On("AUCTION_ITEM_LIST_UPDATE", function()
	if GS.scanning == "classic" then GS:Debounce("scan", 2, processClassic) end
end)
GS:On("REPLICATE_ITEM_LIST_UPDATE", function()
	if GS.scanning == "replicate" then GS:Debounce("scan", 3, processReplicate) end
end)

-- relevante Preise (Items aus Bank-Log der letzten 4 Wochen + Werbungskosten-Liste) an alle verteilen
function GS:BroadcastPrices()
	local g = self:G()
	if not g then return false, L["Keine Gilde"] end
	if not self:HasRight(self.player, "prices") then return false, L["Keine Berechtigung"] end
	local ids = {}
	local minT = self:Now() - 28 * 86400
	for _, e in ipairs(g.bank) do
		if e.i and e.i > 0 and e.t >= minT then ids[e.i] = true end
	end
	for id in pairs(self:GetLatest("wklist").items or {}) do ids[id] = true end
	local p, cnt = {}, 0
	for id in pairs(ids) do
		local e = g.prices[id]
		if e and e.p then
			p[id] = e.p
			cnt = cnt + 1
		end
	end
	if cnt == 0 then return false, L["Keine passenden Scan-Preise vorhanden – zuerst das AH scannen."] end
	self:Broadcast({ t = "PRC", tm = self:Now(), p = p })
	return true, cnt
end

function GS:ReceivePrices(sender, msg)
	local g = self:G()
	if not g or type(msg.p) ~= "table" then return end
	if not self:HasRight(sender, "prices") then
		self:Flag(sender, "Unberechtigt", L["Preise verteilt ohne Recht"])
		return
	end
	local tm = tonumber(msg.tm) or self:Now()
	for id, p in pairs(msg.p) do
		id, p = tonumber(id), tonumber(p)
		if id and p and p > 0 then
			local e = g.prices[id]
			if not e or (e.t or 0) < tm then g.prices[id] = { p = p, t = tm } end
		end
	end
	self:Fire("DATA_CHANGED")
end
