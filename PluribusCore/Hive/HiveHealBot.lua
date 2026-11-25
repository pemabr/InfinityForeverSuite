-- PluribusHealer Unified HealBot + Decursive Engine
-- Combat-safe SecureUnitButtonTemplate raid/party healing grid unified with
-- Decursive class-aware debuff detection, alert chimes, 1-click corner cleanse squares,
-- and toggleable Compact Decursive MUF (Micro-Unit-Frame) mode.
-- Warcraft Forever 1.60.1 (Lua 5.1, zero CLEU, taint-safe deferred combat queue).

PluribusHealDecursive = {
	initialized = false,
	gridFrame = nil,
	unitButtons = {},
	pendingRebuild = false,
	lastSoundAt = 0,
	knownAfflicted = {},
	config = {
		enabled = true,
		showSolo = true,
		locked = false,
		compactMUF = false,       -- false = HealBot + Decursive Corner Cleanse | true = Compact Decursive MUF Squares
		frameWidth = 114,
		frameHeight = 42,
		columns = 5,
		scale = 1.0,
		showIncomingHeals = true,
		showHoTTimers = true,
		fadeOutOfRange = true,
		showAggro = true,
		highlightDebuffs = true,
		onlyDispellable = true,
		alertSound = true,
		point = { "CENTER", 0, -140 },
		bindings = nil,           -- auto-populated from player class & locale via SpellID
		cleansePrimary = nil,     -- auto-populated from player class & locale via SpellID
		cleanseSecondary = nil,   -- auto-populated from player class & locale via SpellID
	},
}
_G.PluribusHealDecursive = PluribusHealDecursive

-- Class-aware dispellable debuff types (Classic / 1.60.1)
PluribusHealDecursive.CLASS_DISPEL_TYPES = {
	PRIEST  = { Magic = true, Disease = true },
	PALADIN = { Magic = true, Poison = true, Disease = true },
	DRUID   = { Curse = true, Poison = true },
	SHAMAN  = { Poison = true, Disease = true },
	MAGE    = { Curse = true },
	WARLOCK = { Magic = true }, -- Felhunter Devour Magic
	WARRIOR = {},
	ROGUE   = {},
	HUNTER  = {},
}

-- Vivid Decursive color palette by WoW dispelType
local DEBUFF_COLORS = {
	Magic   = { r = 0.22, g = 0.74, b = 0.98, tag = "M", hex = "|cff38bdf8" },
	Curse   = { r = 0.68, g = 0.36, b = 0.98, tag = "F", hex = "|cffa855f7" },
	Poison  = { r = 0.24, g = 0.86, b = 0.44, tag = "G", hex = "|cff4ade80" },
	Disease = { r = 0.96, g = 0.72, b = 0.16, tag = "K", hex = "|cfffbbf24" },
}
local DEBUFF_PRIORITY = { Magic = 1, Curse = 2, Poison = 3, Disease = 4 }

-- HoT spell names/IDs tracked on friendly units (EN + DE)
local HOT_SPELLS = {
	{ id = 139,   en = "Renew",              de = "Erneuerung",      tag = "R", r = 0.30, g = 0.92, b = 0.52 },
	{ id = 17,    en = "Power Word: Shield", de = "Machtwort: Schild", tag = "S", r = 0.95, g = 0.95, b = 1.00 },
	{ id = 774,   en = "Rejuvenation",       de = "Verjüngung",      tag = "V", r = 0.85, g = 0.45, b = 0.98 },
	{ id = 8936,  en = "Regrowth",           de = "Nachwachsen",     tag = "N", r = 0.35, g = 0.95, b = 0.68 },
	{ id = 974,   en = "Earth Shield",       de = "Erdschild",       tag = "E", r = 0.96, g = 0.76, b = 0.26 },
}

-- Resolve localized spell name automatically via SpellID (so German clients get German spell names!)
local function ResolveSpell(spellID, fallbackEN, fallbackDE)
	if spellID then
		if C_Spell and C_Spell.GetSpellName then
			local ok, name = pcall(C_Spell.GetSpellName, spellID)
			if ok and name and name ~= "" then return name end
		end
		if GetSpellInfo then
			local ok, name = pcall(GetSpellInfo, spellID)
			if ok and name and name ~= "" then return name end
		end
	end
	local loc = (GetLocale and GetLocale()) or "enUS"
	if loc == "deDE" or loc == "deAT" or loc == "deCH" then
		return fallbackDE or fallbackEN or ""
	end
	return fallbackEN or fallbackDE or ""
end

-- Build locale-accurate class default HealBot click-cast bindings + Decursive cleanse spells
function PluribusHealDecursive:GetClassDefaults(classFile)
	local cls = classFile
	if not cls and UnitClass then
		local _, c = UnitClass("player")
		cls = c
	end
	cls = cls or "PRIEST"

	if cls == "PRIEST" then
		return {
			cleansePrimary = ResolveSpell(527, "Dispel Magic", "Magiebannung"),
			cleanseSecondary = ResolveSpell(552, "Abolish Disease", "Krankheit aufheben"),
			bindings = {
				["Left-Click"]  = ResolveSpell(2061, "Flash Heal", "Blitzheilung"),
				["Right-Click"] = ResolveSpell(2060, "Greater Heal", "Große Heilung"),
				["Middle-Click"]= ResolveSpell(596,  "Prayer of Healing", "Gebet der Heilung"),
				["Shift+Left"]  = ResolveSpell(139,  "Renew", "Erneuerung"),
				["Shift+Right"] = ResolveSpell(17,   "Power Word: Shield", "Machtwort: Schild"),
				["Ctrl+Left"]   = ResolveSpell(527,  "Dispel Magic", "Magiebannung"),
				["Alt+Left"]    = ResolveSpell(552,  "Abolish Disease", "Krankheit aufheben"),
			},
		}
	elseif cls == "DRUID" then
		return {
			cleansePrimary = ResolveSpell(2782, "Remove Curse", "Fluch aufheben"),
			cleanseSecondary = ResolveSpell(2893, "Abolish Poison", "Vergiftung aufheben"),
			bindings = {
				["Left-Click"]  = ResolveSpell(5185, "Healing Touch", "Heilende Berührung"),
				["Right-Click"] = ResolveSpell(8936, "Regrowth", "Nachwachsen"),
				["Middle-Click"]= ResolveSpell(18562,"Swiftmend", "Rasche Heilung"),
				["Shift+Left"]  = ResolveSpell(774,  "Rejuvenation", "Verjüngung"),
				["Shift+Right"] = ResolveSpell(29166,"Innervate", "Anregen"),
				["Ctrl+Left"]   = ResolveSpell(2782, "Remove Curse", "Fluch aufheben"),
				["Alt+Left"]    = ResolveSpell(2893, "Abolish Poison", "Vergiftung aufheben"),
			},
		}
	elseif cls == "PALADIN" then
		return {
			cleansePrimary = ResolveSpell(4987, "Cleanse", "Reinigung des Glaubens"),
			cleanseSecondary = ResolveSpell(1152, "Purify", "Läutern"),
			bindings = {
				["Left-Click"]  = ResolveSpell(19750,"Flash of Light", "Lichtblitz"),
				["Right-Click"] = ResolveSpell(635,  "Holy Light", "Heiliges Licht"),
				["Middle-Click"]= ResolveSpell(20473,"Holy Shock", "Heiliger Schock"),
				["Shift+Left"]  = ResolveSpell(1022, "Blessing of Protection", "Segen des Schutzes"),
				["Shift+Right"] = ResolveSpell(1044, "Blessing of Freedom", "Segen der Freiheit"),
				["Ctrl+Left"]   = ResolveSpell(4987, "Cleanse", "Reinigung des Glaubens"),
				["Alt+Left"]    = ResolveSpell(633,  "Lay on Hands", "Handauflegung"),
			},
		}
	elseif cls == "SHAMAN" then
		return {
			cleansePrimary = ResolveSpell(526,  "Cure Poison", "Vergiftung heilen"),
			cleanseSecondary = ResolveSpell(2870, "Cure Disease", "Krankheit heilen"),
			bindings = {
				["Left-Click"]  = ResolveSpell(8004, "Lesser Healing Wave", "Geringe Welle der Heilung"),
				["Right-Click"] = ResolveSpell(331,  "Healing Wave", "Welle der Heilung"),
				["Middle-Click"]= ResolveSpell(1064, "Chain Heal", "Kettenheilung"),
				["Shift+Left"]  = ResolveSpell(16188,"Nature's Swiftness", "Schnelligkeit der Natur"),
				["Shift+Right"] = ResolveSpell(546,  "Water Walking", "Wasserwandeln"),
				["Ctrl+Left"]   = ResolveSpell(526,  "Cure Poison", "Vergiftung heilen"),
				["Alt+Left"]    = ResolveSpell(2870, "Cure Disease", "Krankheit heilen"),
			},
		}
	elseif cls == "MAGE" then
		return {
			cleansePrimary = ResolveSpell(475, "Remove Lesser Curse", "Geringen Fluch aufheben"),
			cleanseSecondary = ResolveSpell(1459, "Arcane Intellect", "Arkane Intelligenz"),
			bindings = {
				["Left-Click"]  = ResolveSpell(475,  "Remove Lesser Curse", "Geringen Fluch aufheben"),
				["Right-Click"] = ResolveSpell(1459, "Arcane Intellect", "Arkane Intelligenz"),
				["Middle-Click"]= "",
				["Shift+Left"]  = ResolveSpell(604,  "Dampen Magic", "Magie dämpfen"),
				["Shift+Right"] = ResolveSpell(1008, "Amplify Magic", "Magie verstärken"),
				["Ctrl+Left"]   = ResolveSpell(475,  "Remove Lesser Curse", "Geringen Fluch aufheben"),
				["Alt+Left"]    = "",
			},
		}
	else
		return {
			cleansePrimary = "",
			cleanseSecondary = "",
			bindings = {
				["Left-Click"]  = "",
				["Right-Click"] = "",
				["Middle-Click"]= "",
				["Shift+Left"]  = "",
				["Shift+Right"] = "",
				["Ctrl+Left"]   = "",
				["Alt+Left"]    = "",
			},
		}
	end
end

function PluribusHealDecursive:GetPlayerClass()
	if UnitClass then
		local _, c = UnitClass("player")
		return c or "WARRIOR"
	end
	return "WARRIOR"
end

function PluribusHealDecursive:CanPlayerDispel(dispelType)
	if not dispelType then return false end
	local allowed = self.CLASS_DISPEL_TYPES[self:GetPlayerClass()]
	return allowed and allowed[dispelType] == true or false
end

function PluribusHealDecursive:SaveConfig()
	if PluribusStorageManager and PluribusStorageManager.SetAddonSetting then
		PluribusStorageManager:SetAddonSetting("PluribusHealer", "unifiedConfig", self.config)
	end
end

function PluribusHealDecursive:LoadConfig()
	if PluribusStorageManager and PluribusStorageManager.GetAddonSetting then
		local saved = PluribusStorageManager:GetAddonSetting("PluribusHealer", "unifiedConfig")
		if type(saved) == "table" then
			for k, v in pairs(saved) do
				self.config[k] = v
			end
		end
	end
	local defaults = self:GetClassDefaults()
	if type(self.config.bindings) ~= "table" then
		self.config.bindings = defaults.bindings
	end
	if self.config.cleansePrimary == nil then
		self.config.cleansePrimary = defaults.cleansePrimary
	end
	if self.config.cleanseSecondary == nil then
		self.config.cleanseSecondary = defaults.cleanseSecondary
	end
end

function PluribusHealDecursive:ResetClassDefaults()
	local defaults = self:GetClassDefaults()
	self.config.bindings = defaults.bindings
	self.config.cleansePrimary = defaults.cleansePrimary
	self.config.cleanseSecondary = defaults.cleanseSecondary
	self:SaveConfig()
	self:RequestRebuild()
end

-- ============================================================================
-- Aura & Dispellable Debuff Scanners (1.60.1 C_UnitAuras + Classic UnitDebuff)
-- ============================================================================

local function ScanUnitDebuff(unit, onlyDispellable)
	if not unit or not UnitExists or not UnitExists(unit) then return nil end
	local best = nil

	for i = 1, 40 do
		local name, icon, count, dispelType, duration, expirationTime
		if C_UnitAuras and C_UnitAuras.GetDebuffDataByIndex then
			local ok, aura = pcall(C_UnitAuras.GetDebuffDataByIndex, unit, i)
			if not ok or not aura then break end
			name = aura.name
			icon = aura.icon
			count = aura.applications or 0
			dispelType = aura.dispelName
			duration = aura.duration or 0
			expirationTime = aura.expirationTime or 0
		elseif UnitDebuff then
			local n, ic, cnt, dType, dur, exp = UnitDebuff(unit, i)
			if not n then break end
			name, icon, count, dispelType, duration, expirationTime = n, ic, cnt or 0, dType, dur or 0, exp or 0
		else
			break
		end

		if dispelType and DEBUFF_COLORS[dispelType] then
			local canDispel = PluribusHealDecursive:CanPlayerDispel(dispelType)
			if canDispel or not onlyDispellable then
				local prio = DEBUFF_PRIORITY[dispelType] or 9
				if canDispel then prio = prio - 10 end
				if not best or prio < best.prio then
					best = {
						name = name,
						icon = icon,
						count = count or 0,
						dispelType = dispelType,
						duration = duration or 0,
						expirationTime = expirationTime or 0,
						canDispel = canDispel,
						prio = prio,
						color = DEBUFF_COLORS[dispelType],
					}
				end
			end
		end
	end
	return best
end

local function ScanUnitHoTs(unit)
	local found = {}
	if not unit or not UnitExists or not UnitExists(unit) then return found end
	local now = GetTime()

	for i = 1, 40 do
		local name, expirationTime, spellId
		if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
			local ok, aura = pcall(C_UnitAuras.GetBuffDataByIndex, unit, i)
			if not ok or not aura then break end
			name = aura.name
			expirationTime = aura.expirationTime or 0
			spellId = aura.spellId
		elseif UnitBuff then
			local n, _, _, _, _, exp, _, _, _, sid = UnitBuff(unit, i)
			if not n then break end
			name, expirationTime, spellId = n, exp or 0, sid
		else
			break
		end

		if name then
			for _, h in ipairs(HOT_SPELLS) do
				if (spellId and spellId == h.id) or name == h.en or name == h.de then
					local rem = expirationTime > now and math.ceil(expirationTime - now) or 0
					table.insert(found, { tag = h.tag, rem = rem, r = h.r, g = h.g, b = h.b })
					break
				end
			end
		end
		if #found >= 3 then break end
	end
	return found
end

local function IsUnitInHealRange(unit)
	if unit == "player" then return true end
	if UnitInRange then
		local inRange, checked = UnitInRange(unit)
		if checked then return inRange == true end
	end
	if CheckInteractDistance then
		local ok = CheckInteractDistance(unit, 4) -- ~28yd fallback
		if ok ~= nil then return ok == true end
	end
	return true
end

-- ============================================================================
-- Secure Attribute Binding (Strictly Out-of-Combat, Queued If In Combat!)
-- ============================================================================

local function ApplyClickBind(btn, attrPrefix, btnIdx, spellName)
	local s = type(spellName) == "string" and spellName:match("^%s*(.-)%s*$") or ""
	if s ~= "" then
		btn:SetAttribute(attrPrefix .. "type" .. btnIdx, "spell")
		btn:SetAttribute(attrPrefix .. "spell" .. btnIdx, s)
	else
		if attrPrefix == "" and btnIdx == 1 then
			btn:SetAttribute("type1", "target")
			btn:SetAttribute("spell1", nil)
		else
			btn:SetAttribute(attrPrefix .. "type" .. btnIdx, nil)
			btn:SetAttribute(attrPrefix .. "spell" .. btnIdx, nil)
		end
	end
end

function PluribusHealDecursive:ApplyButtonSecureAttributes(tile, unit)
	if InCombatLockdown and InCombatLockdown() then
		self.pendingRebuild = true
		return
	end
	tile:SetAttribute("unit", unit)

	local b = self.config.bindings or {}
	local c1 = self.config.cleansePrimary or ""
	local c2 = self.config.cleanseSecondary or ""

	if self.config.compactMUF then
		-- Compact Decursive MUF Mode: Left-Click = Primary Cleanse, Right-Click = Secondary Cleanse
		ApplyClickBind(tile, "", 1, c1 ~= "" and c1 or b["Left-Click"])
		ApplyClickBind(tile, "", 2, c2 ~= "" and c2 or b["Right-Click"])
		ApplyClickBind(tile, "", 3, b["Middle-Click"])
		ApplyClickBind(tile, "shift-", 1, b["Shift+Left"])
		ApplyClickBind(tile, "shift-", 2, b["Shift+Right"])
		ApplyClickBind(tile, "ctrl-", 1, b["Ctrl+Left"])
		ApplyClickBind(tile, "alt-", 1, b["Alt+Left"])
	else
		-- Full Unified HealBot + Decursive Mode: Click-Cast heals on tile + dedicated 1-click Cleanse corner button
		ApplyClickBind(tile, "", 1, b["Left-Click"])
		ApplyClickBind(tile, "", 2, b["Right-Click"])
		ApplyClickBind(tile, "", 3, b["Middle-Click"])
		ApplyClickBind(tile, "shift-", 1, b["Shift+Left"])
		ApplyClickBind(tile, "shift-", 2, b["Shift+Right"])
		ApplyClickBind(tile, "ctrl-", 1, b["Ctrl+Left"])
		ApplyClickBind(tile, "alt-", 1, b["Alt+Left"])
	end

	if tile.cleanseBtn then
		tile.cleanseBtn:SetAttribute("unit", unit)
		ApplyClickBind(tile.cleanseBtn, "", 1, c1)
		ApplyClickBind(tile.cleanseBtn, "", 2, c2)
	end
end

-- ============================================================================
-- Unified Grid Frame & 40-Unit Secure Tile Pool
-- ============================================================================

local function GetActiveUnitList(showSolo)
	local units = {}
	if IsInRaid and IsInRaid() then
		local n = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
		for i = 1, math.min(40, n) do
			table.insert(units, "raid" .. i)
		end
	elseif (IsInGroup and IsInGroup()) or (GetNumPartyMembers and (GetNumPartyMembers() or 0) > 0) then
		table.insert(units, "player")
		for i = 1, 4 do
			if UnitExists and UnitExists("party" .. i) then
				table.insert(units, "party" .. i)
			end
		end
	elseif showSolo then
		table.insert(units, "player")
	end
	return units
end

function PluribusHealDecursive:CreateUnitTile(parent, index)
	local useKeyDown = (GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and true or false
	-- Pure SecureUnitButtonTemplate (NO BackdropTemplate mixin on secure buttons to avoid Blizzard ADDON_ACTION_BLOCKED taint!)
	local tile = CreateFrame("Button", "PluribusHealTile" .. index, parent, "SecureUnitButtonTemplate")
	tile:RegisterForClicks(useKeyDown and "AnyDown" or "AnyUp")

	-- Taint-free 1px texture border & obsidian fill directly on tile artwork layers
	local borderTex = tile:CreateTexture(nil, "BACKGROUND", nil, -2)
	borderTex:SetAllPoints(tile)
	borderTex:SetColorTexture(0.22, 0.30, 0.42, 0.92)
	tile._borderTex = borderTex

	local fillTex = tile:CreateTexture(nil, "BACKGROUND", nil, -1)
	fillTex:SetPoint("TOPLEFT", tile, "TOPLEFT", 1, -1)
	fillTex:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -1, 1)
	fillTex:SetColorTexture(0.08, 0.11, 0.16, 0.96)
	tile._fillTex = fillTex

	-- Health StatusBar
	local hpBar = CreateFrame("StatusBar", nil, tile)
	hpBar:SetPoint("TOPLEFT", tile, "TOPLEFT", 2, -2)
	hpBar:SetPoint("BOTTOMRIGHT", tile, "BOTTOMRIGHT", -2, 2)
	hpBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	hpBar:SetMinMaxValues(0, 100)
	hpBar:SetValue(100)
	tile.hpBar = hpBar

	local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
	hpBg:SetAllPoints(hpBar)
	if hpBg.SetColorTexture then hpBg:SetColorTexture(0.05, 0.07, 0.10, 0.95)
	else hpBg:SetTexture(0.05, 0.07, 0.10, 0.95) end

	-- Incoming Heal Prediction Overlay
	local incTex = hpBar:CreateTexture(nil, "ARTWORK")
	incTex:SetPoint("TOPLEFT", hpBar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
	incTex:SetPoint("BOTTOMLEFT", hpBar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
	incTex:SetWidth(0)
	if incTex.SetColorTexture then incTex:SetColorTexture(0.30, 0.96, 0.60, 0.55)
	else incTex:SetTexture(0.30, 0.96, 0.60, 0.55) end
	incTex:Hide()
	tile.incTex = incTex

	-- Name & HP text overlay frame (above status bar)
	local overlay = CreateFrame("Frame", nil, hpBar)
	overlay:SetAllPoints(hpBar)
	overlay:SetFrameLevel(hpBar:GetFrameLevel() + 2)

	local nameLbl = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	nameLbl:SetPoint("TOPLEFT", overlay, "TOPLEFT", 4, -3)
	nameLbl:SetPoint("RIGHT", overlay, "RIGHT", -22, 0)
	nameLbl:SetJustifyH("LEFT")
	tile.nameLbl = nameLbl

	local hpLbl = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hpLbl:SetPoint("BOTTOMLEFT", overlay, "BOTTOMLEFT", 4, 3)
	hpLbl:SetJustifyH("LEFT")
	tile.hpLbl = hpLbl

	local hotLbl = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hotLbl:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -4, 3)
	hotLbl:SetJustifyH("RIGHT")
	tile.hotLbl = hotLbl

	-- Dedicated 1-Click Decursive Cleanse Square (pure untainted SecureActionButtonTemplate!)
	local cBtn = CreateFrame("Button", "PluribusDecursiveSquare" .. index, overlay, "SecureActionButtonTemplate")
	cBtn:SetSize(20, 20)
	cBtn:SetPoint("TOPRIGHT", overlay, "TOPRIGHT", -1, -1)
	if useKeyDown then
		cBtn:RegisterForClicks("LeftButtonDown", "RightButtonDown")
	else
		cBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	end
	local cBorder = cBtn:CreateTexture(nil, "BACKGROUND", nil, -2)
	cBorder:SetAllPoints(cBtn)
	cBorder:SetColorTexture(0.25, 0.72, 0.98, 0.95)
	cBtn._borderTex = cBorder
	local cFill = cBtn:CreateTexture(nil, "BACKGROUND", nil, -1)
	cFill:SetPoint("TOPLEFT", cBtn, "TOPLEFT", 1, -1)
	cFill:SetPoint("BOTTOMRIGHT", cBtn, "BOTTOMRIGHT", -1, 1)
	cFill:SetColorTexture(0.08, 0.14, 0.24, 0.95)
	cBtn._fillTex = cFill

	local cTxt = cBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	cTxt:SetPoint("CENTER")
	cTxt:SetText("M")
	cBtn.txt = cTxt
	cBtn:SetScript("OnEnter", function(selfBtn)
		if GameTooltip then
			GameTooltip:SetOwner(selfBtn, "ANCHOR_RIGHT")
			GameTooltip:AddLine("|cff38bdf8Decursive 1-Klick Cleanse|r", 1, 1, 1)
			if selfBtn._debuffInfo then
				local d = selfBtn._debuffInfo
				GameTooltip:AddLine(string.format("%s%s (%s)|r", d.color.hex, tostring(d.name or "Debuff"), tostring(d.dispelType)), 1, 1, 1)
			end
			local c1 = PluribusHealDecursive.config.cleansePrimary or ""
			local c2 = PluribusHealDecursive.config.cleanseSecondary or ""
			if c1 ~= "" then GameTooltip:AddDoubleLine("Linksklick:", "|cff4ade80" .. c1 .. "|r", 0.75, 0.82, 0.90, 1, 1, 1) end
			if c2 ~= "" then GameTooltip:AddDoubleLine("Rechtsklick:", "|cff38bdf8" .. c2 .. "|r", 0.75, 0.82, 0.90, 1, 1, 1) end
			GameTooltip:Show()
		end
	end)
	cBtn:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
	cBtn:Hide()
	tile.cleanseBtn = cBtn

	-- Hover tooltip showing unit HP, debuff & active Click-Cast spells
	tile:SetScript("OnEnter", function(selfTile)
		local u = selfTile.unit
		if not u or not GameTooltip then return end
		GameTooltip:SetOwner(selfTile, "ANCHOR_RIGHT")
		local n = (UnitName and UnitName(u)) or u
		GameTooltip:AddLine("|cffffffff" .. tostring(n) .. "|r", 1, 1, 1)
		if selfTile._debuffInfo then
			local d = selfTile._debuffInfo
			GameTooltip:AddLine(string.format("Debuff: %s%s [%s]|r", d.color.hex, tostring(d.name), tostring(d.dispelType)), 1, 1, 1)
		end
		local b = PluribusHealDecursive.config.bindings or {}
		if PluribusHealDecursive.config.compactMUF then
			local c1 = PluribusHealDecursive.config.cleansePrimary or b["Left-Click"] or ""
			local c2 = PluribusHealDecursive.config.cleanseSecondary or b["Right-Click"] or ""
			if c1 ~= "" then GameTooltip:AddDoubleLine("Linksklick:", "|cff4ade80" .. c1 .. "|r", 0.75, 0.82, 0.90, 1, 1, 1) end
			if c2 ~= "" then GameTooltip:AddDoubleLine("Rechtsklick:", "|cff38bdf8" .. c2 .. "|r", 0.75, 0.82, 0.90, 1, 1, 1) end
		else
			if (b["Left-Click"] or "") ~= "" then GameTooltip:AddDoubleLine("Links:", b["Left-Click"], 0.75, 0.82, 0.90, 0.30, 0.92, 0.52) end
			if (b["Right-Click"] or "") ~= "" then GameTooltip:AddDoubleLine("Rechts:", b["Right-Click"], 0.75, 0.82, 0.90, 0.22, 0.74, 0.98) end
			if (b["Shift+Left"] or "") ~= "" then GameTooltip:AddDoubleLine("Shift+Links:", b["Shift+Left"], 0.75, 0.82, 0.90, 0.96, 0.76, 0.26) end
			if (b["Ctrl+Left"] or "") ~= "" then GameTooltip:AddDoubleLine("Strg+Links:", b["Ctrl+Left"], 0.75, 0.82, 0.90, 0.68, 0.45, 0.98) end
		end
		GameTooltip:Show()
	end)
	tile:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

	tile:Hide()
	return tile
end

function PluribusHealDecursive:CreateGridFrame()
	if self.gridFrame then return self.gridFrame end
	local UI = _G.PluribusUIFramework

	local f = CreateFrame("Frame", "PluribusHealDecursiveGrid", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(240, 80)
	local pt = self.config.point or { "CENTER", 0, -140 }
	f:SetPoint(pt[1] or "CENTER", UIParent, pt[1] or "CENTER", pt[2] or 0, pt[3] or -140)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:SetClampedToScreen(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(selfF)
		if InCombatLockdown and InCombatLockdown() then return end
		if not PluribusHealDecursive.config.locked then
			selfF:StartMoving()
		end
	end)
	f:SetScript("OnDragStop", function(selfF)
		if InCombatLockdown and InCombatLockdown() then return end
		selfF:StopMovingOrSizing()
		local p, _, _, x, y = selfF:GetPoint()
		PluribusHealDecursive.config.point = { p or "CENTER", math.floor(x or 0), math.floor(y or 0) }
		PluribusHealDecursive:SaveConfig()
	end)
	local pal = UI and UI.palette
	if pal then
		UI:ApplyBackdrop(f, pal.bg[1], pal.bg[2], pal.bg[3], 0.94, pal.border[1], pal.border[2], pal.border[3], 0.92)
	else
		UI:ApplyBackdrop(f, 0.06, 0.08, 0.12, 0.94, 0.22, 0.30, 0.42, 0.92)
	end

	-- Compact Header Bar
	local hdr = UI:CreateLabel(f, "|cff38bdf8HealBot + Decursive|r", 1, 1, 1, "GameFontHighlightSmall")
	hdr:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -5)
	f.hdr = hdr

	local closeBtn = UI:CreateButton(f, "x", 16, 15, function()
		if InCombatLockdown and InCombatLockdown() then
			if _G.PluribusUIFramework then
				_G.PluribusUIFramework:ShowNotification("Im Kampf gesperrt — nach dem Kampf ausblenden.", 2.2)
			end
			return
		end
		PluribusHealDecursive.config.enabled = false
		PluribusHealDecursive:SaveConfig()
		f:Hide()
	end)
	closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -3)

	local cfgBtn = UI:CreateButton(f, "Cfg", 28, 15, function()
		if _G.PluribusMainFrame and _G.PluribusMainFrame.OpenToTab then
			_G.PluribusMainFrame:OpenToTab("HealBot")
		elseif _G.PluribusHealerUI and _G.PluribusHealerUI.Toggle then
			_G.PluribusHealerUI:Toggle()
		end
	end)
	cfgBtn:SetPoint("RIGHT", closeBtn, "LEFT", -3, 0)

	local mufBtn = UI:CreateButton(f, "MUF", 32, 15, function()
		PluribusHealDecursive:ToggleCompactMUF()
	end)
	mufBtn:SetPoint("RIGHT", cfgBtn, "LEFT", -3, 0)
	f.mufBtn = mufBtn

	-- Pre-allocate 40 secure unit tiles out of combat
	for i = 1, 40 do
		self.unitButtons[i] = self:CreateUnitTile(f, i)
	end

	-- Live 5Hz visual refresh (HP, incoming heals, HoTs, range, aggro, Decursive debuffs — 100% combat-safe!)
	local accum = 0
	f:SetScript("OnUpdate", function(_, elapsed)
		accum = accum + (elapsed or 0)
		if accum >= 0.18 then
			accum = 0
			PluribusHealDecursive:UpdateAllTilesVisuals()
		end
	end)

	f:Hide()
	self.gridFrame = f
	return f
end

function PluribusHealDecursive:RequestRebuild()
	if InCombatLockdown and InCombatLockdown() then
		self.pendingRebuild = true
		return
	end
	self:RebuildLayout()
end

function PluribusHealDecursive:RebuildLayout()
	if InCombatLockdown and InCombatLockdown() then
		self.pendingRebuild = true
		return
	end
	self.pendingRebuild = false
	local f = self:CreateGridFrame()
	if not self.config.enabled then
		f:Hide()
		return
	end

	local units = GetActiveUnitList(self.config.showSolo == true)
	if #units == 0 then
		f:Hide()
		return
	end

	local compact = self.config.compactMUF == true
	local w = compact and 38 or (tonumber(self.config.frameWidth) or 114)
	local h = compact and 34 or (tonumber(self.config.frameHeight) or 42)
	local cols = compact and math.max(5, math.min(10, tonumber(self.config.columns) or 5)) or math.max(1, math.min(8, tonumber(self.config.columns) or 5))
	local gap = 4
	local pad = 6
	local headerH = 22

	local actualCols = math.min(#units, cols)
	local rows = math.ceil(#units / cols)
	local gridW = math.max(170, pad * 2 + actualCols * w + math.max(0, actualCols - 1) * gap)
	local gridH = headerH + pad + rows * h + math.max(0, rows - 1) * gap + pad

	f:SetScale(tonumber(self.config.scale) or 1.0)
	f:SetSize(gridW, gridH)
	if f.hdr then
		f.hdr:SetText(compact and "|cffa855f7Decursive MUF|r" or "|cff38bdf8HealBot + Decursive|r")
	end
	if f.mufBtn and f.mufBtn.SetActiveState then
		f.mufBtn:SetActiveState(compact)
	end

	for i = 1, 40 do
		local tile = self.unitButtons[i]
		local unit = units[i]
		if unit then
			local col = (i - 1) % cols
			local row = math.floor((i - 1) / cols)
			tile.unit = unit
			tile:ClearAllPoints()
			tile:SetSize(w, h)
			tile:SetPoint("TOPLEFT", f, "TOPLEFT", pad + col * (w + gap), -(headerH + row * (h + gap)))
			self:ApplyButtonSecureAttributes(tile, unit)

			if compact then
				tile.hpLbl:Hide()
				tile.hotLbl:Hide()
				tile.cleanseBtn:Hide()
				tile.nameLbl:ClearAllPoints()
				tile.nameLbl:SetPoint("CENTER", tile.hpBar, "CENTER", 0, 0)
				tile.nameLbl:SetJustifyH("CENTER")
			else
				tile.hpLbl:Show()
				tile.hotLbl:Show()
				tile.nameLbl:ClearAllPoints()
				tile.nameLbl:SetPoint("TOPLEFT", tile.hpBar, "TOPLEFT", 4, -3)
				tile.nameLbl:SetPoint("RIGHT", tile.hpBar, "RIGHT", -22, 0)
				tile.nameLbl:SetJustifyH("LEFT")
			end
			tile:Show()
		else
			tile.unit = nil
			tile:Hide()
		end
	end

	f:Show()
	self:UpdateAllTilesVisuals()
end

-- 100% Combat-Safe Visual Refresh (updates colors, HP, incoming heals, HoTs, Decursive badges)
function PluribusHealDecursive:UpdateAllTilesVisuals()
	if not self.gridFrame or not self.gridFrame:IsVisible() then return end
	local UI = _G.PluribusUIFramework
	local compact = self.config.compactMUF == true
	local anyNewDebuff = false
	local currentAfflicted = {}

	for i = 1, 40 do
		local tile = self.unitButtons[i]
		local unit = tile and tile.unit
		if unit and tile:IsVisible() and UnitExists and UnitExists(unit) then
			local hp = (UnitHealth and UnitHealth(unit)) or 1
			local maxHp = math.max(1, (UnitHealthMax and UnitHealthMax(unit)) or 1)
			local pct = math.floor((hp / maxHp) * 100 + 0.5)
			local isDead = (UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)) or false
			local isOffline = (UnitIsConnected and not UnitIsConnected(unit)) or false
			local uName = (UnitName and UnitName(unit)) or unit
			local _, cls = UnitClass and UnitClass(unit)
			local cr, cg, cb = UI:GetClassColor(cls or "WARRIOR")

			-- Decursive Debuff Scan
			local debuff = self.config.highlightDebuffs and ScanUnitDebuff(unit, self.config.onlyDispellable ~= false) or nil
			tile._debuffInfo = debuff
			if debuff then
				local key = unit .. ":" .. tostring(debuff.name)
				currentAfflicted[key] = true
				if debuff.canDispel and not self.knownAfflicted[key] then
					anyNewDebuff = true
				end
			end

			-- Health bar value & color
			tile.hpBar:SetMinMaxValues(0, maxHp)
			tile.hpBar:SetValue(isDead and 0 or hp)

			if isOffline then
				tile.hpBar:SetStatusBarColor(0.32, 0.36, 0.42, 0.85)
			elseif isDead then
				tile.hpBar:SetStatusBarColor(0.28, 0.14, 0.16, 0.90)
			elseif compact and debuff then
				-- Compact Decursive MUF lights up the entire square in the debuff's color!
				tile.hpBar:SetStatusBarColor(debuff.color.r, debuff.color.g, debuff.color.b, 1)
			else
				tile.hpBar:SetStatusBarColor(cr * 0.85, cg * 0.85, cb * 0.85, 0.95)
			end

			-- Border: Debuff > Aggro > Normal
			local hasAggro = false
			if self.config.showAggro and UnitThreatSituation then
				local threat = UnitThreatSituation(unit)
				hasAggro = (threat ~= nil and threat >= 2)
			end
			if tile._borderTex then
				if debuff then
					tile._borderTex:SetColorTexture(debuff.color.r, debuff.color.g, debuff.color.b, 1)
				elseif hasAggro then
					tile._borderTex:SetColorTexture(0.98, 0.22, 0.22, 1)
				else
					tile._borderTex:SetColorTexture(0.22, 0.30, 0.42, 0.90)
				end
			end

			-- Incoming Heal Prediction Overlay
			if self.config.showIncomingHeals and not compact and not isDead and UnitGetIncomingHeals then
				local inc = UnitGetIncomingHeals(unit) or 0
				if inc > 0 and hp < maxHp then
					local barW = tile.hpBar:GetWidth() or 100
					local incW = math.min(barW * ((maxHp - hp) / maxHp), barW * (inc / maxHp))
					if incW > 1 then
						tile.incTex:SetWidth(incW)
						tile.incTex:Show()
					else
						tile.incTex:Hide()
					end
				else
					tile.incTex:Hide()
				end
			else
				tile.incTex:Hide()
			end

			-- Labels
			if compact then
				if debuff then
					tile.nameLbl:SetText(string.format("|cffffffff%s|r", debuff.color.tag))
				else
					tile.nameLbl:SetText(tostring(uName):sub(1, 3))
				end
			else
				tile.nameLbl:SetText(tostring(uName):sub(1, 11))
				if isOffline then
					tile.hpLbl:SetText("|cff94a3b8Offline|r")
				elseif isDead then
					tile.hpLbl:SetText("|cfff87171Tot|r")
				elseif hp < maxHp then
					local deficit = maxHp - hp
					local defStr = deficit >= 1000 and string.format("-%.1fk", deficit / 1000) or ("-" .. tostring(deficit))
					tile.hpLbl:SetText(string.format("|cfffbbf24%s|r |cffcbd5e1(%d%%)|r", defStr, pct))
				else
					tile.hpLbl:SetText("|cff4ade80100%|r")
				end

				-- HoT Timer Badges
				if self.config.showHoTTimers then
					local hots = ScanUnitHoTs(unit)
					if #hots > 0 then
						local parts = {}
						for _, ht in ipairs(hots) do
							table.insert(parts, string.format("|cff4ade80%s%s|r", ht.tag, ht.rem > 0 and tostring(ht.rem) or ""))
						end
						tile.hotLbl:SetText(table.concat(parts, " "))
					else
						tile.hotLbl:SetText("")
					end
				else
					tile.hotLbl:SetText("")
				end

				-- Integrated 1-Click Decursive Corner Cleanse Square (Note: combat-safe alpha/visual update; visibility toggled only out-of-combat OR always ready when cleanse spell configured)
				if tile.cleanseBtn then
					tile.cleanseBtn._debuffInfo = debuff
					if debuff then
						if tile.cleanseBtn._fillTex then tile.cleanseBtn._fillTex:SetColorTexture(debuff.color.r * 0.65, debuff.color.g * 0.65, debuff.color.b * 0.65, 1) end
						if tile.cleanseBtn._borderTex then tile.cleanseBtn._borderTex:SetColorTexture(debuff.color.r, debuff.color.g, debuff.color.b, 1) end
						local rem = (debuff.expirationTime and debuff.expirationTime > GetTime()) and math.ceil(debuff.expirationTime - GetTime()) or 0
						tile.cleanseBtn.txt:SetText(rem > 0 and (debuff.color.tag .. rem) or debuff.color.tag)
						tile.cleanseBtn:SetAlpha(1.0)
						if not (InCombatLockdown and InCombatLockdown()) then
							tile.cleanseBtn:Show()
						end
					else
						if not (InCombatLockdown and InCombatLockdown()) then
							-- Keep shown at dim alpha if player has a cleanse spell so it stays 1-click ready during combat!
							if (self.config.cleansePrimary or "") ~= "" then
								tile.cleanseBtn:Show()
								if tile.cleanseBtn._fillTex then tile.cleanseBtn._fillTex:SetColorTexture(0.08, 0.11, 0.16, 0.45) end
								if tile.cleanseBtn._borderTex then tile.cleanseBtn._borderTex:SetColorTexture(0.25, 0.35, 0.48, 0.45) end
								tile.cleanseBtn.txt:SetText("|cff64748b+|r")
								tile.cleanseBtn:SetAlpha(0.32)
							else
								tile.cleanseBtn:Hide()
							end
						else
							tile.cleanseBtn:SetAlpha(0.25)
							tile.cleanseBtn.txt:SetText("|cff64748b+|r")
						end
					end
				end
			end

			-- 40yd Range Fade
			if self.config.fadeOutOfRange and not isDead and not isOffline then
				local inRange = IsUnitInHealRange(unit)
				tile:SetAlpha(inRange and 1.0 or 0.42)
			else
				tile:SetAlpha(isOffline and 0.45 or 1.0)
			end
		end
	end

	self.knownAfflicted = currentAfflicted

	-- Rate-limited Decursive Alert Chime when a new dispellable debuff lands
	if anyNewDebuff and self.config.alertSound and PlaySound then
		local now = GetTime()
		if (now - self.lastSoundAt) >= 2.5 then
			self.lastSoundAt = now
			pcall(PlaySound, 8959) -- RaidWarning / crisp chime
		end
	end
end

function PluribusHealDecursive:SetAlwaysShow(val)
	self.config.showSolo = (val == true)
	if self.config.showSolo then
		self.config.enabled = true
	end
	self:SaveConfig()
	self:RequestRebuild()
end

function PluribusHealDecursive:ToggleGrid()
	if InCombatLockdown and InCombatLockdown() then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("Im Kampf gesperrt — nach dem Kampf umschalten.", 2.2)
		end
		return
	end
	self.config.enabled = not self.config.enabled
	if self.config.enabled and not (IsInGroup and IsInGroup()) and not (IsInRaid and IsInRaid()) then
		self.config.showSolo = true
	end
	self:SaveConfig()
	self:RequestRebuild()
end

function PluribusHealDecursive:ToggleCompactMUF()
	if InCombatLockdown and InCombatLockdown() then
		if _G.PluribusUIFramework then
			_G.PluribusUIFramework:ShowNotification("MUF-Modus wechselt automatisch nach dem Kampf.", 2.2)
		end
		self.config.compactMUF = not self.config.compactMUF
		self:SaveConfig()
		self.pendingRebuild = true
		return
	end
	self.config.compactMUF = not self.config.compactMUF
	self.config.enabled = true
	if not (IsInGroup and IsInGroup()) and not (IsInRaid and IsInRaid()) then
		self.config.showSolo = true
	end
	self:SaveConfig()
	self:RebuildLayout()
end

function PluribusHealDecursive:Initialize()
	if self.initialized then return end
	self.initialized = true
	self:LoadConfig()

	local ev = CreateFrame("Frame")
	pcall(ev.RegisterEvent, ev, "PLAYER_ENTERING_WORLD")
	pcall(ev.RegisterEvent, ev, "GROUP_ROSTER_UPDATE")
	pcall(ev.RegisterEvent, ev, "PARTY_MEMBERS_CHANGED")
	pcall(ev.RegisterEvent, ev, "RAID_ROSTER_UPDATE")
	pcall(ev.RegisterEvent, ev, "PLAYER_REGEN_ENABLED")
	pcall(ev.RegisterEvent, ev, "UNIT_AURA")
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" then
			if PluribusHealDecursive.pendingRebuild then
				PluribusHealDecursive:RebuildLayout()
			end
		elseif event == "UNIT_AURA" then
			PluribusHealDecursive:UpdateAllTilesVisuals()
		else
			PluribusHealDecursive:RequestRebuild()
		end
	end)

	self:RequestRebuild()
end

return PluribusHealDecursive
