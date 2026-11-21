-- Finanzamt – Sprache: Deutsch ist die Grundsprache (Schlüssel = deutscher Text),
-- Übersetzungen liegen in Locale_en_*.lua. Die Sprache wird pro WoW-Account gewählt
-- (beim ersten Start abgefragt), nicht aus der Client-Sprache übernommen.
local GS = select(2, ...).GS

GS.LANGS = { "de", "en" }
GS.LANG_NAMES = { de = "Deutsch", en = "English" }
GS.LOCALES = { en = {} }

-- aktive Sprache: gespeicherte Wahl, sonst Client-Sprache (bis zur Abfrage).
-- Wird beim Laden festgelegt; eine neue Wahl gilt erst nach dem Neuladen der Oberfläche.
function GS:Lang()
	if self.activeLang then return self.activeLang end
	local db = self.db
	local l = db and db.lang
	if l and (l == "de" or self.LOCALES[l]) then return l end
	local loc = GetLocale and GetLocale()
	return (loc == "deDE") and "de" or "en"
end

-- L["Deutscher Text"] liefert den Text in der aktiven Sprache (fehlt die Übersetzung: Deutsch)
local L = setmetatable({}, {
	__index = function(_, key)
		if type(key) ~= "string" then return key end
		local lang = GS:Lang()
		if lang ~= "de" then
			local t = GS.LOCALES[lang]
			local v = t and t[key]
			if v then return v end
		end
		return key
	end,
})
GS.L = L
GS:Register("DB_READY", function() GS.activeLang = nil; GS.activeLang = GS:Lang() end)

-- LF("Erfolge %d / %d", n, N): übersetzen, dann formatieren
function GS.LF(key, ...)
	return string.format(L[key], ...)
end

-- Text in einer bestimmten Sprache (z. B. Erfolgsnamen beider Sprachen erkennen)
function GS:LangText(key, lang)
	if lang == "de" or type(key) ~= "string" then return key end
	local t = self.LOCALES[lang]
	return (t and t[key]) or key
end

---------------------------------------------------------------------------
-- Sprache wählen
---------------------------------------------------------------------------
function GS:SetLang(lang, reload)
	if lang ~= "de" and not self.LOCALES[lang] then return false end
	local before = self:Lang()
	self.db.lang = lang
	if before == lang then self.activeLang = lang end
	if reload and before ~= lang and ReloadUI then
		ReloadUI()
	end
	return true, before ~= lang
end

local picker
function GS:ShowLangPicker()
	if not picker then
		local f = CreateFrame("Frame", "FinanzamtLangPicker", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		f:SetSize(320, 130)
		f:SetPoint("CENTER", 0, 120)
		f:SetFrameStrata("DIALOG")
		if f.SetBackdrop then
			f:SetBackdrop({
				bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
				edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
				tile = true, tileSize = 32, edgeSize = 32,
				insets = { left = 11, right = 12, top = 12, bottom = 11 },
			})
		end
		f:EnableMouse(true)
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", f.StopMovingOrSizing)
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		title:SetPoint("TOP", 0, -18)
		title:SetText("Finanzamt")
		local text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOP", 0, -44)
		text:SetText("Sprache wählen  ·  Choose your language")
		local function btn(lang, x)
			local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
			b:SetSize(120, 24)
			b:SetPoint("BOTTOM", x, 20)
			b:SetText(GS.LANG_NAMES[lang])
			b:SetScript("OnClick", function()
				f:Hide()
				local _, changed = GS:SetLang(lang, false)
				if changed and ReloadUI then
					ReloadUI() -- Oberfläche ist schon in der alten Sprache aufgebaut
				else
					GS:Fire("LANG_CHOSEN")
				end
			end)
			return b
		end
		btn("de", -66)
		btn("en", 66)
		picker = f
	end
	picker:Show()
end

-- nach dem Login einmal fragen, solange noch keine Sprache gewählt ist
GS:On("PLAYER_LOGIN", function()
	C_Timer.After(2, function()
		if GS.db and not GS.db.lang then GS:ShowLangPicker() end
	end)
end)
