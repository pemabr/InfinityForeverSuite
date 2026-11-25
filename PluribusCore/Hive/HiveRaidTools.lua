-- PluribusHive Raid & Group Tools
-- 1) Auto-showing Draggable Raid/Party Marker Bar (8 Target Icons + 8 World Pins + Pull Countdown + Ready Check)
-- 2) On-Screen Pull Countdown Timer Bar (PLBHIVE + DBM/BigWigs D4 compatible + /rw or /p ticks)
-- 3) Enhanced Ready Check Inspector (Active Buffs, Consumables, Class-Aware Missing Buffs & Armor Durability %)

PluribusHiveRaidTools = {
	initialized = false,
	markerBar = nil,
	worldPinRow = nil,
	worldPinButtons = {},
	worldPinsExpanded = true,
	forceShowBar = false,
	_pendingBarUpdate = false,
	pullDuration = 10,
	pullEndTime = 0,
	pullLastTick = 0,
	pullBar = nil,
	readyFrame = nil,
	readyStates = {},       -- [canonKey] = "READY" | "NOTREADY" | "WAITING"
	peerReadyInfo = {},     -- [canonKey] = { durPct, mhEnch, ohEnch, updatedAt }
	readyCheckActive = false,
}
_G.PluribusHiveRaidTools = PluribusHiveRaidTools

local function L(key, ...)
	if _G.PluribusL and _G.PluribusL.Get then
		return _G.PluribusL:Get(key, ...)
	end
	return key
end

local RAID_ICON_COORDS = {
	[1] = { 0.00, 0.25, 0.00, 0.25, "Stern / Star" },
	[2] = { 0.25, 0.50, 0.00, 0.25, "Kreis / Circle" },
	[3] = { 0.50, 0.75, 0.00, 0.25, "Diamant / Diamond" },
	[4] = { 0.75, 1.00, 0.00, 0.25, "Dreieck / Triangle" },
	[5] = { 0.00, 0.25, 0.25, 0.50, "Mond / Moon" },
	[6] = { 0.25, 0.50, 0.25, 0.50, "Quadrat / Square" },
	[7] = { 0.50, 0.75, 0.25, 0.50, "Kreuz / Cross" },
	[8] = { 0.75, 1.00, 0.25, 0.50, "Totenkopf / Skull" },
}

-- World Marker definitions aligned with Row 1 Target Icons (Skull -> Star)
-- WoW PlaceRaidMarker / /wm index mapping: 1=Blue Square, 2=Green Triangle, 3=Purple Diamond,
-- 4=Red Cross, 5=Yellow Star, 6=Orange Circle, 7=Silver Moon, 8=White Skull
local WORLD_PIN_DEFS = {
	{ wm = 8, targetIcon = 8, label = "W", name = "Weiß / Totenkopf", color = { 0.96, 0.96, 0.98 } },
	{ wm = 4, targetIcon = 7, label = "R", name = "Rot / Kreuz",      color = { 0.94, 0.28, 0.28 } },
	{ wm = 1, targetIcon = 6, label = "B", name = "Blau / Quadrat",   color = { 0.18, 0.58, 0.98 } },
	{ wm = 7, targetIcon = 5, label = "S", name = "Silber / Mond",    color = { 0.78, 0.84, 0.92 } },
	{ wm = 2, targetIcon = 4, label = "G", name = "Grün / Dreieck",   color = { 0.20, 0.84, 0.42 } },
	{ wm = 3, targetIcon = 3, label = "V", name = "Lila / Diamant",   color = { 0.74, 0.36, 0.96 } },
	{ wm = 6, targetIcon = 2, label = "O", name = "Orange / Kreis",   color = { 0.98, 0.54, 0.16 } },
	{ wm = 5, targetIcon = 1, label = "Y", name = "Gelb / Stern",     color = { 0.98, 0.82, 0.18 } },
}
local WORLD_PIN_BY_WM = {}
for _, wp in ipairs(WORLD_PIN_DEFS) do
	WORLD_PIN_BY_WM[wp.wm] = wp
end

-- EN + DE Classic Buff & Consumable patterns
local BUFF_PATTERNS = {
	FORT = {
		"fortitude", "seelenstärke", "prayer of fortitude", "gebet der seelenstärke",
	},
	INT = {
		"arcane intellect", "arcane brilliance", "arkane intelligenz", "arkane brillanz",
	},
	MOTW = {
		"mark of the wild", "gift of the wild", "mal der wildnis", "gabe der wildnis",
	},
	SPIRIT = {
		"divine spirit", "prayer of spirit", "göttlicher wille", "gebet der willenskraft",
	},
	BLESSING = {
		"blessing of", "greater blessing", "segen der", "segen des", "großer segen",
	},
	FLASK = {
		"flask of", "fläschchen", "oberste macht", "supreme power", "destillierte weisheit",
		"distilled wisdom", "titanen", "titans", "chromatischer widerstand", "chromatic resistance",
	},
	FOOD = {
		"well fed", "satt", "gesegnete sonnenfrucht", "blessed sunfruit", "geräucherter", "dumpling",
	},
	ELIXIR = {
		"elixir", "elixier", "mungo", "mongoose", "riesen", "giants", "feuermacht", "firepower",
		"schattenmacht", "shadow power", "frostmacht", "frost power", "arkanes elixier", "arcane elixir",
		"mageblood", "magierblut", "juju", "firewater", "feuerwasser",
	},
}

local MANA_CLASSES = {
	MAGE = true, PRIEST = true, WARLOCK = true, PALADIN = true, SHAMAN = true, DRUID = true, HUNTER = true,
}

local function IsInPartyOrRaid()
	if IsInRaid and IsInRaid() then return true end
	if IsInGroup and IsInGroup() then return true end
	if GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0 then return true end
	if GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0 then return true end
	return false
end

local function GetGroupChannel()
	if IsInRaid and IsInRaid() then return "RAID" end
	if GetNumRaidMembers and (GetNumRaidMembers() or 0) > 0 then return "RAID" end
	if IsInGroup and IsInGroup() then return "PARTY" end
	if GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0 then return "PARTY" end
	return nil
end

local function CanRaidWarn()
	if UnitIsGroupLeader and UnitIsGroupLeader("player") then return true end
	if UnitIsGroupAssistant and UnitIsGroupAssistant("player") then return true end
	if IsRaidLeader and IsRaidLeader() then return true end
	if IsRaidOfficer and IsRaidOfficer() then return true end
	return false
end

local function GetUnitBuffName(unit, index)
	if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
		local ok, data = pcall(C_UnitAuras.GetBuffDataByIndex, unit, index)
		if ok and data and data.name then return data.name end
	end
	if UnitBuff then
		local ok, name = pcall(UnitBuff, unit, index)
		if ok and name then return name end
	end
	return nil
end

-- ============================================================================
-- 1. DURABILITY & READY CHECK BUFF / CONSUMABLE INSPECTOR
-- ============================================================================

function PluribusHiveRaidTools:GetPlayerDurabilityPct()
	if not GetInventoryItemDurability then return 100 end
	local curTotal, maxTotal = 0, 0
	for slot = 1, 18 do
		local ok, cur, mx = pcall(GetInventoryItemDurability, slot)
		if ok and cur and mx and mx > 0 then
			curTotal = curTotal + cur
			maxTotal = maxTotal + mx
		end
	end
	if maxTotal <= 0 then return 100 end
	return math.floor((curTotal / maxTotal) * 100 + 0.5)
end

function PluribusHiveRaidTools:BroadcastMyReadyInfo()
	if not _G.PluribusHive then return end
	local dur = self:GetPlayerDurabilityPct()
	local mh, oh = 0, 0
	if GetWeaponEnchantInfo then
		local ok, hasMH, _, _, _, hasOH = pcall(GetWeaponEnchantInfo)
		if ok then
			mh = hasMH and 1 or 0
			oh = hasOH and 1 or 0
		end
	end
	local meKey = PluribusHive:CanonicalKey(PluribusHive:GetPlayerShortName())
	self.peerReadyInfo[meKey] = { durPct = dur, mhEnch = mh == 1, ohEnch = oh == 1, updatedAt = time() }
	local ch = GetGroupChannel()
	if ch then
		PluribusHive:Send("READYINFO", string.format("%d|%d|%d", dur, mh, oh), ch, nil, true)
	end
end

function PluribusHiveRaidTools:GetGroupUnits()
	local units = {}
	if IsInRaid and IsInRaid() then
		local n = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
		for i = 1, n do
			local u = "raid" .. i
			if UnitExists and UnitExists(u) then table.insert(units, u) end
		end
	elseif IsInPartyOrRaid() then
		table.insert(units, "player")
		for i = 1, 4 do
			local u = "party" .. i
			if UnitExists and UnitExists(u) then table.insert(units, u) end
		end
	else
		table.insert(units, "player")
	end
	return units
end

function PluribusHiveRaidTools:ScanGroupBuffsAndDurability()
	local units = self:GetGroupUnits()
	local classPresent = {}
	for _, u in ipairs(units) do
		local _, cls = UnitClass(u)
		if cls then classPresent[cls] = true end
	end

	local meKey = _G.PluribusHive and PluribusHive:CanonicalKey(PluribusHive:GetPlayerShortName()) or ""
	if meKey ~= "" then
		self.peerReadyInfo[meKey] = self.peerReadyInfo[meKey] or { durPct = self:GetPlayerDurabilityPct(), updatedAt = time() }
		self.peerReadyInfo[meKey].durPct = self:GetPlayerDurabilityPct()
	end

	local rows = {}
	local stats = { total = 0, ready = 0, notReady = 0, flask = 0, food = 0, lowDur = 0 }

	for _, u in ipairs(units) do
		local rawName = UnitName(u) or u
		local short = _G.PluribusHive and PluribusHive:NormalizeName(rawName) or rawName:gsub("%-.+$", "")
		local cKey = _G.PluribusHive and PluribusHive:CanonicalKey(short) or short:lower()
		local _, cls = UnitClass(u)
		cls = cls or "WARRIOR"

		local found = {}
		for bi = 1, 40 do
			local bName = GetUnitBuffName(u, bi)
			if not bName then break end
			local low = bName:lower()
			for tag, pats in pairs(BUFF_PATTERNS) do
				if not found[tag] then
					for _, pat in ipairs(pats) do
						if low:find(pat, 1, true) then
							found[tag] = true
							break
						end
					end
				end
			end
		end

		local pInfo = self.peerReadyInfo[cKey]
		local durPct = pInfo and pInfo.durPct or nil
		local hasOil = pInfo and (pInfo.mhEnch or pInfo.ohEnch) or false

		local haveList = {}
		if found.FLASK then table.insert(haveList, "Flask") end
		if found.FOOD then table.insert(haveList, "Satt") end
		if found.ELIXIR then table.insert(haveList, "Elixier") end
		if hasOil then table.insert(haveList, "Öl/Stein") end
		if found.FORT then table.insert(haveList, "Ausd.") end
		if found.MOTW then table.insert(haveList, "MdW") end
		if found.INT then table.insert(haveList, "Int") end
		if found.BLESSING then table.insert(haveList, "Segen") end
		if found.SPIRIT then table.insert(haveList, "Wille") end

		-- Class-aware missing buffs & consumables (only flags buffs whose provider class is in the group!)
		local missingList = {}
		if not found.FLASK and not found.ELIXIR then
			table.insert(missingList, "Flask/Elixier")
		end
		if not found.FOOD then
			table.insert(missingList, "Satt")
		end
		if classPresent.PRIEST and not found.FORT then
			table.insert(missingList, "Seelenstärke")
		end
		if classPresent.DRUID and not found.MOTW then
			table.insert(missingList, "MdW")
		end
		if classPresent.MAGE and MANA_CLASSES[cls] and not found.INT then
			table.insert(missingList, "Intelligenz")
		end
		if classPresent.PALADIN and not found.BLESSING then
			table.insert(missingList, "Segen")
		end

		local rState = self.readyStates[cKey] or "WAITING"
		stats.total = stats.total + 1
		if rState == "READY" then stats.ready = stats.ready + 1
		elseif rState == "NOTREADY" then stats.notReady = stats.notReady + 1 end
		if found.FLASK then stats.flask = stats.flask + 1 end
		if found.FOOD then stats.food = stats.food + 1 end
		if durPct and durPct < 50 then stats.lowDur = stats.lowDur + 1 end

		table.insert(rows, {
			unit = u,
			name = short,
			canonKey = cKey,
			class = cls,
			readyState = rState,
			haveList = haveList,
			missingList = missingList,
			durPct = durPct,
			isOnline = UnitIsConnected and UnitIsConnected(u) ~= false,
		})
	end

	table.sort(rows, function(a, b)
		if #a.missingList ~= #b.missingList then return #a.missingList > #b.missingList end
		return (a.name or "") < (b.name or "")
	end)
	return rows, stats
end

function PluribusHiveRaidTools:OpenReadyCheckInspector()
	local UI = _G.PluribusUIFramework
	if not UI then return end

	if not self.readyFrame then
		local f = UI:CreateFrame("PluribusReadyCheckFrame", UIParent, 680, 410,
			L("RC_TITLE"), L("RC_SUBTITLE"))
		f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
		f:SetFrameStrata("HIGH")

		local sumLbl = UI:CreateLabel(f, "", 0.92, 0.96, 1.0, "GameFontHighlightSmall")
		sumLbl:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -48)
		f.sumLbl = sumLbl

		local postBtn = UI:CreateButton(f, L("RC_POST_MISSING"), 126, 22, function()
			PluribusHiveRaidTools:PostMissingToChat()
		end)
		postBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -44)

		local refBtn = UI:CreateButton(f, L("REFRESH"), 86, 22, function()
			PluribusHiveRaidTools:BroadcastMyReadyInfo()
			local ch = GetGroupChannel()
			if ch and _G.PluribusHive then
				PluribusHive:Send("RC_REQ", "1", ch, nil, true)
			end
			PluribusHiveRaidTools:RefreshReadyCheckInspector()
		end, true)
		refBtn:SetPoint("RIGHT", postBtn, "LEFT", -6, 0)

		-- Column headers
		local hdr = UI:CreateCard(f, 652, 22)
		hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -72)
		local h1 = UI:CreateLabel(hdr, "Spieler", 0.72, 0.82, 0.94, "GameFontHighlightSmall")
		h1:SetPoint("LEFT", hdr, "LEFT", 28, 0)
		local h2 = UI:CreateLabel(hdr, "Aktive Buffs & Consumables", 0.45, 0.90, 0.60, "GameFontHighlightSmall")
		h2:SetPoint("LEFT", hdr, "LEFT", 156, 0)
		local h3 = UI:CreateLabel(hdr, "Fehlt", 0.98, 0.62, 0.48, "GameFontHighlightSmall")
		h3:SetPoint("LEFT", hdr, "LEFT", 374, 0)
		local h4 = UI:CreateLabel(hdr, "Haltbarkeit", 0.98, 0.84, 0.36, "GameFontHighlightSmall")
		h4:SetPoint("RIGHT", hdr, "RIGHT", -10, 0)

		local scroll = UI:CreateScrollFrame(f, "PluribusReadyCheckScroll", 652, 294)
		scroll:SetPoint("TOPLEFT", hdr, "BOTTOMLEFT", 0, -4)
		f.scroll = scroll

		self.readyFrame = f
	end

	self.readyFrame:Show()
	UI:BringToFront(self.readyFrame)
	self:RefreshReadyCheckInspector()
end

function PluribusHiveRaidTools:RefreshReadyCheckInspector()
	local f = self.readyFrame
	if not f or not f:IsShown() or not _G.PluribusUIFramework then return end
	local UI = _G.PluribusUIFramework
	local rows, stats = self:ScanGroupBuffsAndDurability()

	f.sumLbl:SetText(string.format(
		"Bereit: |cff4ade80%d/%d|r · Nicht bereit: |cfff87171%d|r · Flask: |cff38bdf8%d|r · Satt: |cff4ade80%d|r · Haltbarkeit <50%%: |cfffbbf24%d|r",
		stats.ready, stats.total, stats.notReady, stats.flask, stats.food, stats.lowDur))

	local c = f.scroll.content
	UI:ClearContainer(c)
	local y = -2
	for idx, r in ipairs(rows) do
		local row = UI:CreateListRow(c, 624, 28, idx)
		row:SetPoint("TOPLEFT", c, "TOPLEFT", 0, y)

		local stateStr = (r.readyState == "READY" and "|cff4ade80[OK]|r")
			or (r.readyState == "NOTREADY" and "|cfff87171[NO]|r")
			or "|cfffbbf24[?]|r"
		local lSt = UI:CreateLabel(row, stateStr, 1, 1, 1, "GameFontHighlightSmall")
		lSt:SetPoint("LEFT", row, "LEFT", 4, 0)

		local _, _, _, hex = UI:GetClassColor(r.class)
		local lName = UI:CreateLabel(row, hex .. r.name .. "|r")
		lName:SetPoint("LEFT", row, "LEFT", 36, 0)
		lName:SetWidth(114)
		if lName.SetWordWrap then lName:SetWordWrap(false) end

		local haveStr = #r.haveList > 0 and table.concat(r.haveList, ", ") or "|cff64748b—|r"
		local lHave = UI:CreateLabel(row, "|cff86efac" .. haveStr .. "|r", 1, 1, 1, "GameFontHighlightSmall")
		lHave:SetPoint("LEFT", row, "LEFT", 156, 0)
		lHave:SetWidth(210)
		if lHave.SetWordWrap then lHave:SetWordWrap(false) end

		local missStr = #r.missingList > 0 and ("|cfff87171" .. table.concat(r.missingList, ", ") .. "|r") or "|cff4ade80Vollständig|r"
		local lMiss = UI:CreateLabel(row, missStr, 1, 1, 1, "GameFontHighlightSmall")
		lMiss:SetPoint("LEFT", row, "LEFT", 374, 0)
		lMiss:SetWidth(182)
		if lMiss.SetWordWrap then lMiss:SetWordWrap(false) end

		local durStr
		if r.durPct == nil then
			durStr = "|cff64748b—|r"
		elseif r.durPct >= 80 then
			durStr = string.format("|cff4ade80%d%%|r", r.durPct)
		elseif r.durPct >= 50 then
			durStr = string.format("|cfffbbf24%d%%|r", r.durPct)
		else
			durStr = string.format("|cfff87171%d%%!|r", r.durPct)
		end
		local lDur = UI:CreateLabel(row, durStr, 1, 1, 1, "GameFontNormal")
		lDur:SetPoint("RIGHT", row, "RIGHT", -8, 0)

		y = y - 30
	end
	c:SetHeight(math.max(280, math.abs(y) + 10))
end

function PluribusHiveRaidTools:PostMissingToChat()
	local ch = GetGroupChannel()
	if not ch or not SendChatMessage then return end
	local rows = self:ScanGroupBuffsAndDurability()
	local missingMsgs = {}
	local lowDurList = {}
	for _, r in ipairs(rows) do
		if #r.missingList > 0 and #missingMsgs < 6 then
			table.insert(missingMsgs, r.name .. ": " .. table.concat(r.missingList, "/"))
		end
		if r.durPct and r.durPct < 50 then
			table.insert(lowDurList, string.format("%s (%d%%)", r.name, r.durPct))
		end
	end
	if #missingMsgs > 0 then
		pcall(SendChatMessage, "[Pluribus ReadyCheck] Fehlende Buffs/Cons: " .. table.concat(missingMsgs, " | "), ch)
	else
		pcall(SendChatMessage, "[Pluribus ReadyCheck] Alle Buffs & Consumables vollständig!", ch)
	end
	if #lowDurList > 0 then
		pcall(SendChatMessage, "[Pluribus ReadyCheck] Niedrige Haltbarkeit (<50%): " .. table.concat(lowDurList, ", "), ch)
	end
end

-- ============================================================================
-- 2. PULL COUNTDOWN TIMER (PLBHIVE + DBM/BigWigs D4 + On-Screen Progress Bar)
-- ============================================================================

function PluribusHiveRaidTools:EnsurePullBar()
	if self.pullBar then return self.pullBar end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end

	local bar = CreateFrame("Frame", "PluribusPullTimerBar", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	bar:SetSize(280, 38)
	bar:SetPoint("TOP", UIParent, "TOP", 0, -140)
	bar:SetFrameStrata("HIGH")
	UI:ApplyBackdrop(bar, 0.05, 0.08, 0.14, 0.94, 0.96, 0.56, 0.16, 0.95)

	local status = UI:CreateStatusBar(bar, 266, 24, 0.96, 0.56, 0.16)
	status:SetPoint("CENTER", bar, "CENTER", 0, 0)
	bar.status = status
	bar:Hide()

	bar:SetScript("OnUpdate", function(selfBar)
		local rem = PluribusHiveRaidTools.pullEndTime - GetTime()
		if rem <= 0 then
			selfBar:Hide()
			if PluribusHiveRaidTools.pullLastTick > 0 then
				PluribusHiveRaidTools.pullLastTick = 0
				if PluribusHiveRaidTools._pullOwner then
					local ch = CanRaidWarn() and "RAID_WARNING" or GetGroupChannel()
					if ch and SendChatMessage then
						pcall(SendChatMessage, ">>> PULL! <<<", ch)
					end
					PluribusHiveRaidTools._pullOwner = false
				end
				if RaidNotice_AddMessage and RaidWarningFrame then
					pcall(RaidNotice_AddMessage, RaidWarningFrame, "|cff4ade80>>> PULL! <<<|r", { r = 0.29, g = 0.87, b = 0.50 })
				end
				if PlaySound then pcall(PlaySound, 8959) end
			end
			return
		end
		local total = math.max(1, PluribusHiveRaidTools._pullTotal or 10)
		local pct = math.max(0, math.min(100, (rem / total) * 100))
		selfBar.status:SetBarData(pct, "PULL COUNTDOWN", string.format("%.1fs", rem), 0.96, 0.56, 0.16)

		local sec = math.ceil(rem)
		if sec ~= PluribusHiveRaidTools.pullLastTick then
			PluribusHiveRaidTools.pullLastTick = sec
			if sec <= 5 or sec == 10 then
				if RaidNotice_AddMessage and RaidWarningFrame then
					pcall(RaidNotice_AddMessage, RaidWarningFrame, string.format("|cfffbbf24Pull in %d...|r", sec), { r = 0.98, g = 0.78, b = 0.22 })
				end
				if PluribusHiveRaidTools._pullOwner and (sec <= 3 or sec == 5 or sec == 10) then
					local ch = CanRaidWarn() and "RAID_WARNING" or GetGroupChannel()
					if ch and SendChatMessage then
						pcall(SendChatMessage, string.format("Pull in %d...", sec), ch)
					end
				end
			end
		end
	end)

	self.pullBar = bar
	return bar
end

function PluribusHiveRaidTools:StartPullCountdown(seconds, fromRemote)
	local dur = tonumber(seconds) or self.pullDuration or 10
	if dur <= 0 then
		self.pullEndTime = 0
		self.pullLastTick = 0
		self._pullOwner = false
		if self.pullBar then self.pullBar:Hide() end
		if not fromRemote and _G.PluribusHive then
			local ch = GetGroupChannel()
			if ch then PluribusHive:Send("PULL", "0", ch, nil, true) end
		end
		return
	end

	self._pullTotal = dur
	self.pullEndTime = GetTime() + dur
	self.pullLastTick = dur + 1
	self._pullOwner = not fromRemote

	local bar = self:EnsurePullBar()
	if bar then bar:Show() end

	if not fromRemote then
		local ch = GetGroupChannel()
		if ch then
			if _G.PluribusHive then
				PluribusHive:Send("PULL", tostring(dur), ch, nil, true)
			end
			-- DBM / BigWigs compatible Pull Timer broadcast
			if C_ChatInfo and C_ChatInfo.SendAddonMessage then
				pcall(C_ChatInfo.SendAddonMessage, "D4", "PT\t" .. tostring(dur), ch)
			elseif SendAddonMessage then
				pcall(SendAddonMessage, "D4", "PT\t" .. tostring(dur), ch)
			end
		end
	end
end

-- ============================================================================
-- 3. AUTO-SHOWING DRAGGABLE RAID / PARTY MARKER BAR (SYMBOLS + PINS + PULL + RC)
-- ============================================================================

function PluribusHiveRaidTools:RefreshWorldMarkerStates()
	if not self.worldPinButtons then return end
	local checkActive = _G.IsRaidMarkerActive
	for _, entry in ipairs(self.worldPinButtons) do
		local active = false
		if checkActive then
			local ok, res = pcall(checkActive, entry.wm)
			active = ok and (res == true)
		end
		local c = entry.color
		if entry.bg and entry.bg.SetBackdropBorderColor then
			if active then
				entry.bg:SetBackdropColor(c[1] * 0.42, c[2] * 0.42, c[3] * 0.42, 0.98)
				entry.bg:SetBackdropBorderColor(1.0, 0.92, 0.35, 1.0)
			else
				entry.bg:SetBackdropColor(c[1] * 0.22, c[2] * 0.22, c[3] * 0.22, 0.92)
				entry.bg:SetBackdropBorderColor(c[1], c[2], c[3], 0.92)
			end
		end
		if entry.activeDot then
			entry.activeDot:SetShown(active)
		end
	end
end

function PluribusHiveRaidTools:ApplyMarkerBarLayout()
	if not self.markerBar then return end
	if InCombatLockdown and InCombatLockdown() then
		self._pendingBarUpdate = true
		return
	end
	local expanded = self.worldPinsExpanded ~= false
	self.markerBar:SetSize(468, expanded and 64 or 36)
	if self.worldPinRow then
		self.worldPinRow:SetShown(expanded)
	end
	if self.pinToggleBtn and self.pinToggleBtn.SetActiveState then
		self.pinToggleBtn:SetActiveState(expanded)
	end
end

function PluribusHiveRaidTools:CreateMarkerBar()
	if self.markerBar then return self.markerBar end
	if InCombatLockdown and InCombatLockdown() then
		self._pendingBarUpdate = true
		return nil
	end
	local UI = _G.PluribusUIFramework
	if not UI then return nil end

	local cfg = _G.PluribusHive and PluribusHive:GetConfig() or {}
	self.worldPinsExpanded = (cfg.markerBarShowWorldMarkers ~= false)

	local bar = CreateFrame("Frame", "PluribusRaidMarkerBar", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	bar:SetSize(468, self.worldPinsExpanded and 64 or 36)
	bar:SetPoint("TOP", UIParent, "TOP", 0, -56)
	bar:SetMovable(true)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetClampedToScreen(true)
	bar:SetFrameStrata("MEDIUM")
	UI:ApplyBackdrop(bar, 0.05, 0.08, 0.13, 0.92, 0.22, 0.34, 0.48, 0.90)

	bar:SetScript("OnDragStart", function(selfF)
		if InCombatLockdown and InCombatLockdown() then return end
		selfF:StartMoving()
	end)
	bar:SetScript("OnDragStop", function(selfF)
		if InCombatLockdown and InCombatLockdown() then return end
		selfF:StopMovingOrSizing()
		local p1, _, p2, x, y = selfF:GetPoint()
		if _G.PluribusHive then
			PluribusHive:SetConfig("markerBarPos", { p1 = p1, p2 = p2, x = math.floor(x or 0), y = math.floor(y or 0) })
		end
	end)

	-- Restore saved position if any
	local savedPos = cfg.markerBarPos
	if type(savedPos) == "table" and savedPos.p1 then
		bar:ClearAllPoints()
		bar:SetPoint(savedPos.p1, UIParent, savedPos.p2 or savedPos.p1, savedPos.x or 0, savedPos.y or -56)
	end

	-- Row 1 Label ("Ziel")
	local row1Lbl = UI:CreateLabel(bar, "Ziel", 0.65, 0.76, 0.88, "GameFontHighlightSmall")
	row1Lbl:SetPoint("TOPLEFT", bar, "TOPLEFT", 8, -11)

	-- Row 1: 8 Target Raid Icons (Skull -> Star)
	local x = 36
	for idx = 8, 1, -1 do
		local info = RAID_ICON_COORDS[idx]
		local btn = CreateFrame("Button", nil, bar)
		btn:SetSize(22, 22)
		btn:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -7)
		local tex = btn:CreateTexture(nil, "ARTWORK")
		tex:SetAllPoints()
		tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		tex:SetTexCoord(info[1], info[2], info[3], info[4])
		btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		btn:SetScript("OnClick", function()
			if SetRaidTarget then pcall(SetRaidTarget, "target", idx) end
		end)
		btn:SetScript("OnEnter", function(selfB)
			if GameTooltip then
				GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
				GameTooltip:AddLine("Ziel markieren: " .. info[5], 1, 1, 1)
				GameTooltip:Show()
			end
		end)
		btn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		x = x + 24
	end

	-- Clear Target Mark button
	local clrBtn = UI:CreateButton(bar, "X", 22, 22, function()
		if SetRaidTarget then pcall(SetRaidTarget, "target", 0) end
	end)
	clrBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -7)
	clrBtn:SetScript("OnEnter", function(selfB)
		if GameTooltip then
			GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("Ziel-Markierung entfernen", 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	clrBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	x = x + 28

	-- Pull Countdown Button (Left = Start/Cancel, Right = cycle 5/10/15/20s)
	local pullBtn
	pullBtn = UI:CreateButton(bar, "Pull " .. tostring(self.pullDuration) .. "s", 64, 22, function(_, mouseBtn)
		if mouseBtn == "RightButton" then
			local opts = { 5, 10, 15, 20 }
			local nextDur = 10
			for i, v in ipairs(opts) do
				if v == PluribusHiveRaidTools.pullDuration then
					nextDur = opts[(i % #opts) + 1]
					break
				end
			end
			PluribusHiveRaidTools.pullDuration = nextDur
			if pullBtn.label then pullBtn.label:SetText("Pull " .. tostring(nextDur) .. "s") end
		else
			if PluribusHiveRaidTools.pullEndTime > GetTime() then
				PluribusHiveRaidTools:StartPullCountdown(0, false)
			else
				PluribusHiveRaidTools:StartPullCountdown(PluribusHiveRaidTools.pullDuration, false)
			end
		end
	end, true)
	pullBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	pullBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -7)
	pullBtn:SetScript("OnEnter", function(selfB)
		if GameTooltip then
			GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("|cfffbbf24Pull-Countdown|r", 1, 1, 1)
			GameTooltip:AddLine("Linksklick: Pull-Timer starten / abbrechen", 0.85, 0.92, 1)
			GameTooltip:AddLine("Rechtsklick: Dauer wechseln (5 / 10 / 15 / 20s)", 0.75, 0.85, 0.95)
			GameTooltip:Show()
		end
	end)
	pullBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	x = x + 68

	-- Ready Check Button (Triggers DoReadyCheck + opens Buff/Consumable/Durability Inspector!)
	local rcBtn = UI:CreateButton(bar, "Bereit?", 56, 22, function(_, mouseBtn)
		if mouseBtn ~= "RightButton" and DoReadyCheck and CanRaidWarn() then
			pcall(DoReadyCheck)
		end
		PluribusHiveRaidTools:BroadcastMyReadyInfo()
		local ch = GetGroupChannel()
		if ch and _G.PluribusHive then
			PluribusHive:Send("RC_REQ", "1", ch, nil, true)
		end
		PluribusHiveRaidTools:OpenReadyCheckInspector()
	end)
	rcBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	rcBtn:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -7)
	rcBtn:SetScript("OnEnter", function(selfB)
		if GameTooltip then
			GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("|cff4ade80Bereitschaftscheck + Buff/Haltbarkeit|r", 1, 1, 1)
			GameTooltip:AddLine("Linksklick: Bereitschaftscheck starten & Übersicht öffnen", 0.85, 0.92, 1)
			GameTooltip:AddLine("Rechtsklick: Nur Buff-/Consumable-/Haltbarkeits-Check öffnen", 0.75, 0.85, 0.95)
			GameTooltip:Show()
		end
	end)
	rcBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	x = x + 60

	-- Toggle World Markers (Ortsmarkierungen) visibility row
	local pinToggle = UI:CreateButton(bar, "Orte", 44, 22, function()
		if InCombatLockdown and InCombatLockdown() then
			if _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification("|cfffbbf24Ortsmarkierungen können im Kampf nicht umgeklappt werden.|r", 2.5)
			end
			return
		end
		PluribusHiveRaidTools.worldPinsExpanded = not PluribusHiveRaidTools.worldPinsExpanded
		if _G.PluribusHive then
			PluribusHive:SetConfig("markerBarShowWorldMarkers", PluribusHiveRaidTools.worldPinsExpanded)
		end
		PluribusHiveRaidTools:ApplyMarkerBarLayout()
	end)
	pinToggle:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -7)
	if pinToggle.SetActiveState then pinToggle:SetActiveState(self.worldPinsExpanded) end
	pinToggle:SetScript("OnEnter", function(selfB)
		if GameTooltip then
			GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("|cff38bdf8Ortsmarkierungen (World Markers)|r", 1, 1, 1)
			GameTooltip:AddLine("Zeile für Ortsmarkierungen ein-/ausklappen", 0.78, 0.85, 0.95)
			GameTooltip:Show()
		end
	end)
	pinToggle:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	self.pinToggleBtn = pinToggle

	-- Row 2 (Integrated directly inside the Marker Bar!): Warcraft Forever Ortsmarkierungen (World Markers 1..8)
	local pinRow = CreateFrame("Frame", "PluribusRaidWorldPinRow", bar)
	pinRow:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -33)
	pinRow:SetSize(468, 28)

	local div = pinRow:CreateTexture(nil, "ARTWORK")
	div:SetColorTexture(0.22, 0.34, 0.48, 0.45)
	div:SetPoint("TOPLEFT", pinRow, "TOPLEFT", 8, 0)
	div:SetPoint("TOPRIGHT", pinRow, "TOPRIGHT", -8, 0)
	div:SetHeight(1)

	local row2Lbl = UI:CreateLabel(pinRow, "Ort", 0.45, 0.82, 0.98, "GameFontHighlightSmall")
	row2Lbl:SetPoint("LEFT", pinRow, "LEFT", 8, -1)

	local hasNativeWM = (_G.PlaceRaidMarker ~= nil) or (_G.ClearRaidMarker ~= nil)
	local useKeyDown = (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false
	self.worldPinButtons = {}

	local px = 36
	for _, wp in ipairs(WORLD_PIN_DEFS) do
		local c = wp.color
		local tInfo = RAID_ICON_COORDS[wp.targetIcon]

		-- Separate non-secure visual frame behind the secure button (prevents Blizzard BackdropTemplate taint!)
		local bg = CreateFrame("Frame", nil, pinRow, BackdropTemplateMixin and "BackdropTemplate" or nil)
		bg:SetSize(22, 22)
		bg:SetPoint("LEFT", pinRow, "LEFT", px, -1)
		UI:ApplyBackdrop(bg, c[1] * 0.22, c[2] * 0.22, c[3] * 0.22, 0.92, c[1], c[2], c[3], 0.92)

		local iconTex = bg:CreateTexture(nil, "ARTWORK")
		iconTex:SetSize(16, 16)
		iconTex:SetPoint("CENTER", bg, "CENTER", 0, 0)
		iconTex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
		if tInfo then
			iconTex:SetTexCoord(tInfo[1], tInfo[2], tInfo[3], tInfo[4])
		end

		local activeDot = bg:CreateTexture(nil, "OVERLAY")
		activeDot:SetSize(5, 5)
		activeDot:SetPoint("TOPRIGHT", bg, "TOPRIGHT", -1, -1)
		activeDot:SetColorTexture(1.0, 0.92, 0.28, 1.0)
		activeDot:Hide()

		-- Pure untainted SecureActionButtonTemplate (zero BackdropTemplate, zero HookScript!)
		local pBtn = CreateFrame("Button", "PluribusWorldMarkerBtn" .. tostring(wp.wm), pinRow, "SecureActionButtonTemplate")
		pBtn:SetSize(22, 22)
		pBtn:SetPoint("CENTER", bg, "CENTER", 0, 0)
		pBtn:SetFrameLevel((bg:GetFrameLevel() or 5) + 2)
		if useKeyDown then
			pBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
		else
			pBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		end

		if hasNativeWM then
			pBtn:SetAttribute("type1", "worldmarker")
			pBtn:SetAttribute("marker1", wp.wm)
			pBtn:SetAttribute("action1", "set")
			pBtn:SetAttribute("shift-type1", "macro")
			pBtn:SetAttribute("shift-macrotext1", "/wm [@cursor] " .. tostring(wp.wm))
			pBtn:SetAttribute("type2", "worldmarker")
			pBtn:SetAttribute("marker2", wp.wm)
			pBtn:SetAttribute("action2", "clear")
		else
			pBtn:SetAttribute("type1", "macro")
			pBtn:SetAttribute("macrotext1", "/wm " .. tostring(wp.wm))
			pBtn:SetAttribute("shift-type1", "macro")
			pBtn:SetAttribute("shift-macrotext1", "/wm [@cursor] " .. tostring(wp.wm))
			pBtn:SetAttribute("type2", "macro")
			pBtn:SetAttribute("macrotext2", "/cwm " .. tostring(wp.wm))
		end
		pBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

		table.insert(self.worldPinButtons, { wm = wp.wm, btn = pBtn, bg = bg, color = c, activeDot = activeDot })

		pBtn:SetScript("OnEnter", function(selfB)
			if GameTooltip then
				GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
				GameTooltip:AddLine("Ortsmarkierung: " .. wp.name, c[1], c[2], c[3])
				GameTooltip:AddLine("Linksklick: Ortsmarkierung platzieren", 0.85, 0.92, 1)
				GameTooltip:AddLine("Shift+Linksklick: Sofort am Mauszeiger setzen", 0.78, 0.88, 0.98)
				GameTooltip:AddLine("Rechtsklick: Diese Ortsmarkierung entfernen", 0.95, 0.72, 0.72)
				GameTooltip:Show()
			end
		end)
		pBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
		px = px + 24
	end

	-- Clear ALL World Markers button aligned directly under Clear Target ("X") — pure untainted SecureActionButtonTemplate
	local cwmBg = CreateFrame("Frame", nil, pinRow, BackdropTemplateMixin and "BackdropTemplate" or nil)
	cwmBg:SetSize(22, 22)
	cwmBg:SetPoint("LEFT", pinRow, "LEFT", px, -1)
	UI:ApplyBackdrop(cwmBg, 0.24, 0.09, 0.11, 0.95, 0.92, 0.34, 0.34, 0.92)
	local cwmLbl = UI:CreateLabel(cwmBg, "X", 0.98, 0.76, 0.76, "GameFontHighlightSmall")
	cwmLbl:SetPoint("CENTER")

	local cwmBtn = CreateFrame("Button", "PluribusWorldMarkerClearAllBtn", pinRow, "SecureActionButtonTemplate")
	cwmBtn:SetSize(22, 22)
	cwmBtn:SetPoint("CENTER", cwmBg, "CENTER", 0, 0)
	cwmBtn:SetFrameLevel((cwmBg:GetFrameLevel() or 5) + 2)
	cwmBtn:RegisterForClicks(useKeyDown and "LeftButtonDown" or "LeftButtonUp")
	if hasNativeWM then
		cwmBtn:SetAttribute("type1", "worldmarker")
		cwmBtn:SetAttribute("action1", "clear")
	else
		cwmBtn:SetAttribute("type1", "macro")
		cwmBtn:SetAttribute("macrotext1", "/cwm all")
	end
	cwmBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	cwmBtn:SetScript("OnEnter", function(selfB)
		if GameTooltip then
			GameTooltip:SetOwner(selfB, "ANCHOR_BOTTOM")
			GameTooltip:AddLine("|cfff87171Alle Ortsmarkierungen entfernen|r", 1, 1, 1)
			GameTooltip:AddLine("Löscht sämtliche gesetzten Welt-/Ortsmarkierungen.", 0.82, 0.88, 0.95)
			GameTooltip:Show()
		end
	end)
	cwmBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	local hintLbl = UI:CreateLabel(pinRow, "|cff94a3b8L: Setzen · Shift+L: Cursor · R: Löschen|r", 1, 1, 1, "GameFontHighlightSmall")
	hintLbl:SetPoint("LEFT", cwmBg, "RIGHT", 8, 0)

	-- Passive 1Hz visual refresh of active world-marker dots (zero PostClick hook on secure buttons!)
	local wmAccum = 0
	pinRow:SetScript("OnUpdate", function(_, elapsed)
		wmAccum = wmAccum + (elapsed or 0)
		if wmAccum >= 0.8 then
			wmAccum = 0
			PluribusHiveRaidTools:RefreshWorldMarkerStates()
		end
	end)

	pinRow:SetShown(self.worldPinsExpanded)
	self.worldPinRow = pinRow
	self.markerBar = bar
	self:RefreshWorldMarkerStates()
	return bar
end

function PluribusHiveRaidTools:UpdateMarkerBarVisibility()
	if InCombatLockdown and InCombatLockdown() then
		self._pendingBarUpdate = true
		return
	end
	local cfg = _G.PluribusHive and PluribusHive:GetConfig() or {}
	if cfg.showRaidMarkerBar == false and not self.forceShowBar then
		if self.markerBar then self.markerBar:Hide() end
		return
	end
	if IsInPartyOrRaid() or self.forceShowBar then
		local bar = self:CreateMarkerBar()
		if bar then
			bar:Show()
			self:ApplyMarkerBarLayout()
			self:RefreshWorldMarkerStates()
		end
	else
		if self.markerBar then self.markerBar:Hide() end
	end
end

function PluribusHiveRaidTools:ToggleMarkerBar()
	if InCombatLockdown and InCombatLockdown() then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("|cfffbbf24Markierungsleiste kann im Kampf nicht umgeschaltet werden.|r", 2.5)
		end
		return
	end
	self.forceShowBar = not self.forceShowBar
	local bar = self:CreateMarkerBar()
	if bar then
		if self.forceShowBar or IsInPartyOrRaid() then
			bar:Show()
			self:ApplyMarkerBarLayout()
			self:RefreshWorldMarkerStates()
		else
			bar:Hide()
		end
	end
end

function PluribusHiveRaidTools:Initialize()
	if self.initialized then return end
	self.initialized = true

	if _G.PluribusHive then
		PluribusHive:RegisterHandler("PULL", function(_, body)
			local sec = tonumber(body) or 0
			PluribusHiveRaidTools:StartPullCountdown(sec, true)
		end)
		PluribusHive:RegisterHandler("RC_REQ", function()
			PluribusHiveRaidTools:BroadcastMyReadyInfo()
		end)
		PluribusHive:RegisterHandler("READYINFO", function(sender, body)
			local durStr, mhStr, ohStr = body:match("^(%d+)|(%d+)|(%d+)$")
			local cKey = PluribusHive:CanonicalKey(sender)
			if cKey ~= "" and durStr then
				PluribusHiveRaidTools.peerReadyInfo[cKey] = {
					durPct = tonumber(durStr) or 100,
					mhEnch = mhStr == "1",
					ohEnch = ohStr == "1",
					updatedAt = time(),
				}
				PluribusHiveRaidTools:RefreshReadyCheckInspector()
			end
		end)
		PluribusHive:RegisterHandler("WPIN", function(sender, body)
			local wmStr, zone, xStr, yStr, midStr = body:match("^(%d+)|([^|]*)|([^|]*)|([^|]*)|?(.*)$")
			local wm = tonumber(wmStr)
			local x, y = tonumber(xStr), tonumber(yStr)
			if wm and x and y and _G.PluribusNavigationUI and _G.PluribusNavigationUI.AddMapPin then
				local def = WORLD_PIN_BY_WM[wm]
				local label = string.format("[%s] %s (%s)", def and def.label or "P", def and def.name or "Pin", sender)
				_G.PluribusNavigationUI:AddMapPin(label, zone or "Azeroth", x * 100, y * 100, tonumber(midStr) or 0)
			end
		end)
	end

	local evFrame = CreateFrame("Frame")
	pcall(evFrame.RegisterEvent, evFrame, "PLAYER_ENTERING_WORLD")
	pcall(evFrame.RegisterEvent, evFrame, "GROUP_ROSTER_UPDATE")
	pcall(evFrame.RegisterEvent, evFrame, "PARTY_MEMBERS_CHANGED")
	pcall(evFrame.RegisterEvent, evFrame, "RAID_ROSTER_UPDATE")
	pcall(evFrame.RegisterEvent, evFrame, "RAID_TARGET_UPDATE")
	pcall(evFrame.RegisterEvent, evFrame, "PLAYER_REGEN_ENABLED")
	pcall(evFrame.RegisterEvent, evFrame, "READY_CHECK")
	pcall(evFrame.RegisterEvent, evFrame, "READY_CHECK_CONFIRM")
	pcall(evFrame.RegisterEvent, evFrame, "READY_CHECK_FINISHED")

	evFrame:SetScript("OnEvent", function(_, event, arg1, arg2)
		if event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE"
			or event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
			PluribusHiveRaidTools:UpdateMarkerBarVisibility()
		elseif event == "RAID_TARGET_UPDATE" then
			PluribusHiveRaidTools:RefreshWorldMarkerStates()
		elseif event == "PLAYER_REGEN_ENABLED" then
			if PluribusHiveRaidTools._pendingBarUpdate then
				PluribusHiveRaidTools._pendingBarUpdate = false
				PluribusHiveRaidTools:UpdateMarkerBarVisibility()
			end
		elseif event == "READY_CHECK" then
			PluribusHiveRaidTools.readyCheckActive = true
			PluribusHiveRaidTools.readyStates = {}
			if arg1 and _G.PluribusHive then
				PluribusHiveRaidTools.readyStates[PluribusHive:CanonicalKey(arg1)] = "READY"
			end
			PluribusHiveRaidTools:BroadcastMyReadyInfo()
			local cfg = _G.PluribusHive and PluribusHive:GetConfig() or {}
			if cfg.autoShowReadyCheck ~= false then
				PluribusHiveRaidTools:OpenReadyCheckInspector()
			end
		elseif event == "READY_CHECK_CONFIRM" then
			local unit = arg1
			local isReady = arg2
			if unit and UnitName and _G.PluribusHive then
				local uName = UnitName(unit)
				if uName then
					local cKey = PluribusHive:CanonicalKey(uName)
					PluribusHiveRaidTools.readyStates[cKey] = isReady and "READY" or "NOTREADY"
					PluribusHiveRaidTools:RefreshReadyCheckInspector()
				end
			end
		elseif event == "READY_CHECK_FINISHED" then
			PluribusHiveRaidTools.readyCheckActive = false
			PluribusHiveRaidTools:RefreshReadyCheckInspector()
		end
	end)

	self:UpdateMarkerBarVisibility()
end

return PluribusHiveRaidTools
