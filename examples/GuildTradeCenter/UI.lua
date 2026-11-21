local GTC = GuildTradeCenter
local L = GTC.T

-- Alle Farben werden zentral ueber das aktive Theme gesteuert.
local THEMES = {
    dark = {
        label = "GTC Dark",
        panel = {0.055, 0.075, 0.105, 0.98},
        card = {0.105, 0.135, 0.175, 1},
        cardHover = {0.14, 0.19, 0.23, 1},
        gold = {0.78, 0.63, 0.32, 1},
        cyan = {0.20, 0.82, 0.85, 1},
        text = {0.90, 0.92, 0.94, 1},
        muted = {0.62, 0.69, 0.77, 1},
        green = {0.40, 0.82, 0.58, 1},
        red = {0.90, 0.40, 0.35, 1},
        border = {0.22, 0.29, 0.35, 1},
        listPanel = {0.035, 0.05, 0.075, 1},
        detailPanel = {0.045, 0.065, 0.09, 1},
        iconPanel = {0.16, 0.20, 0.25, 1},
        characterBackground = {0.035, 0.075, 0.09, 0.92},
        characterHover = {0.10, 0.72, 0.80, 0.24},
        characterBorder = {0.20, 0.78, 0.84, 0.90},
        button = {0.055, 0.075, 0.105, 1},
        buttonHover = {0.20, 0.82, 0.85, 0.24},
        buttonPressed = {0.12, 0.17, 0.21, 1},
        buttonDisabled = {0.07, 0.08, 0.09, 1},
        buttonText = {0.90, 0.82, 0.60, 1},
        buttonBorder = {0.65, 0.52, 0.29, 1},
        inputBackground = {0.025, 0.04, 0.06, 1},
        inputBorder = {0.22, 0.29, 0.35, 1},
    },
    azeroth = {
        label = "Azeroth",
        panel = {0.075, 0.052, 0.033, 0.98},
        card = {0.15, 0.095, 0.055, 1},
        cardHover = {0.22, 0.14, 0.075, 1},
        gold = {0.88, 0.68, 0.32, 1},
        cyan = {0.86, 0.63, 0.28, 1},
        text = {0.94, 0.88, 0.76, 1},
        muted = {0.70, 0.60, 0.45, 1},
        green = {0.46, 0.75, 0.42, 1},
        red = {0.86, 0.35, 0.25, 1},
        border = {0.46, 0.31, 0.15, 1},
        listPanel = {0.055, 0.036, 0.025, 1},
        detailPanel = {0.085, 0.055, 0.032, 1},
        iconPanel = {0.12, 0.08, 0.045, 1},
        characterBackground = {0.05, 0.032, 0.02, 0.94},
        characterHover = {0.88, 0.65, 0.24, 0.18},
        characterBorder = {0.90, 0.68, 0.30, 0.95},
        button = {0.12, 0.075, 0.04, 1},
        buttonHover = {0.90, 0.68, 0.30, 0.24},
        buttonPressed = {0.22, 0.14, 0.07, 1},
        buttonDisabled = {0.08, 0.06, 0.04, 1},
        buttonText = {0.94, 0.78, 0.48, 1},
        buttonBorder = {0.75, 0.54, 0.25, 1},
        inputBackground = {0.05, 0.032, 0.02, 1},
        inputBorder = {0.46, 0.31, 0.15, 1},
    },
    clean = {
        label = "Clean",
        panel = {0.055, 0.07, 0.085, 0.98},
        card = {0.095, 0.125, 0.155, 1},
        cardHover = {0.14, 0.18, 0.22, 1},
        gold = {0.65, 0.78, 0.90, 1},
        cyan = {0.30, 0.72, 0.92, 1},
        text = {0.90, 0.94, 0.98, 1},
        muted = {0.58, 0.68, 0.78, 1},
        green = {0.36, 0.78, 0.63, 1},
        red = {0.88, 0.39, 0.39, 1},
        border = {0.27, 0.36, 0.45, 1},
        listPanel = {0.035, 0.05, 0.065, 1},
        detailPanel = {0.055, 0.075, 0.10, 1},
        iconPanel = {0.09, 0.13, 0.17, 1},
        characterBackground = {0.025, 0.055, 0.075, 0.92},
        characterHover = {0.30, 0.72, 0.92, 0.22},
        characterBorder = {0.30, 0.72, 0.92, 0.90},
        button = {0.10, 0.15, 0.20, 1},
        buttonHover = {0.30, 0.72, 0.92, 0.24},
        buttonPressed = {0.07, 0.12, 0.17, 1},
        buttonDisabled = {0.05, 0.07, 0.09, 1},
        buttonText = {0.88, 0.94, 0.98, 1},
        buttonBorder = {0.30, 0.62, 0.80, 1},
        inputBackground = {0.025, 0.04, 0.06, 1},
        inputBorder = {0.27, 0.36, 0.45, 1},
    },
}

-- Zunaechst sicherer Standard. Das gespeicherte Theme wird beim
-- Erstellen des Fensters erneut geladen, sobald die DB verfuegbar ist.
local activeThemeKey = "dark"
local C = THEMES.dark

-- Eigener Dialog fuer Rueckmeldungen aus dem GTC-Eintragsformular.
local function ShowGTCItemFeedbackPopup(message)
    local popupText = tostring(message or L("Der Eintrag konnte nicht gespeichert werden."))

    if type(StaticPopupDialogs) == "table" and type(StaticPopup_Show) == "function" then
        StaticPopupDialogs["GTC_ITEM_FEEDBACK_POPUP"] = {
            text = "%s",
            button1 = OKAY or "OK",
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }
        StaticPopup_Show("GTC_ITEM_FEEDBACK_POPUP", popupText)
    else
        GTC:Print(popupText)
    end
end

local function LoadActiveTheme()
    activeThemeKey = "dark"

    if type(GuildTradeCenterDB) == "table"
        and type(GuildTradeCenterDB.theme) == "string"
        and THEMES[GuildTradeCenterDB.theme] then
        activeThemeKey = GuildTradeCenterDB.theme
    end

    C = THEMES[activeThemeKey] or THEMES.dark
end

-- Einheitliche Tooltips fuer Buttons und Bedienelemente.
local function AddTooltip(frame, title, text)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L(title), 1, 1, 1)
        if text then
            GameTooltip:AddLine(L(text), 0.75, 0.84, 0.97, true)
        end
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

-- Tooltips nach Button-Beschriftung (Lua-Muster, beim Erstellen ausgewertet).
local BUTTON_TIPS = {
    { "^Angebote$", "Angebote", "Zeigt alle Angebote der Gilde: Gegenstände, die Mitglieder abgeben oder tauschen möchten." },
    { "^Gesuche$", "Gesuche", "Zeigt alle Gesuche der Gilde: Gegenstände, die Mitglieder suchen." },
    { "^Rezepte$", "Rezepte der Gilde", "Alle Rezepte, die Gildenmitglieder herstellen können, mit Materialien sowie BoP- und Online-Filter." },
    { "^Eintrag erstellen$", "Eintrag erstellen", "Legt ein eigenes Angebot oder Gesuch an und teilt es mit der Gilde." },
    { "^Scannen$", "Inventar scannen", "Liest Taschen (und Bank, wenn sie offen ist) aus und ergänzt den Item-Katalog. Läuft auch automatisch bei Änderungen." },
    { "^Design: ", "Design wählen", "Wechselt das Farbschema. Das Fenster wird dabei neu aufgebaut." },
    { "^Handel:", "Handelsart filtern", "Filtert die Liste nach Tausch, Verkauf, Kostenlos oder Kaufe." },
    { "^Status:", "Status filtern", "Zeigt alle, nur aktive oder nur abgeschlossene Einträge." },
    { "^Qualität", "Qualität filtern", "Wählt eine oder mehrere Itemqualitäten, zum Beispiel Selten oder Episch." },
    { "^Reset$", "Filter zurücksetzen", "Setzt Suche, Handelsart, Status, Qualität und Nur eigene zurück." },
    { "^Alle$", "Alle Qualitäten", "Hebt den Qualitätsfilter auf." },
    { "^Fertig$", "Fertig", "Schließt dieses Auswahlmenü." },
    { "^< Zurück zur Liste$", "Zurück zur Liste", "Schließt die Detailansicht und zeigt wieder die Liste." },
    { "^Bearbeiten$", "Eintrag bearbeiten", "Ändert Gegenstand, Menge, Handelsart, Beschreibung oder Laufzeit deines Eintrags." },
    { "^Löschen$", "Eintrag löschen", "Entfernt deinen Eintrag und meldet das der Gilde." },
    { "^Von Gilde laden$", "Katalog von der Gilde laden", "Fragt den Item-Katalog bei Gildenmitgliedern an. Es werden nur Item-IDs übertragen, Namen und Bindung lädt dein Spiel selbst nach. Nur auf Knopfdruck, kein ständiger Abgleich." },
    { "^Item einfügen$", "Item in Beschreibung einfügen", "Wählt einen Gegenstand aus dem Katalog und fügt seinen Link in die Beschreibung ein. Alternativ geht auch Shift-Klick auf einen Gegenstand (Taschen, Chat) bei aktivem Beschreibungsfeld." },
    { "^Aus Katalog$", "Aus Katalog wählen", "Öffnet den Item-Katalog der Gilde, um einen bekannten Gegenstand zu übernehmen." },
    { "^Schließen$", "Schließen", "Schließt dieses Fenster." },
    { "^Angebot$", "Als Angebot eintragen", "Du gibst den Gegenstand ab: Verkauf, Tausch oder kostenlos." },
    { "^Gesuch$", "Als Gesuch eintragen", "Du suchst den Gegenstand: Kauf oder Tausch." },
    { "^Speichern$", "Eintrag speichern", "Speichert den Eintrag lokal und teilt ihn mit der Gilde. BoP-Gegenstände sind nicht erlaubt." },
    { "^Abbrechen$", "Abbrechen", "Verwirft die Eingaben und kehrt zur Liste zurück." },
    { "^< Zurück$", "Vorherige Seite", "Blättert in der Liste eine Seite zurück." },
    { "^Weiter >$", "Nächste Seite", "Blättert in der Liste eine Seite weiter." },
    { "^Zurück$", "Zurück", "Zurück zum Handelsbrett." },
    { "^%?$", "Info und Feedback", "Zeigt Informationen zu GTC, den Sync-Status und den Link für Feedback." },
}

local function FindButtonTip(label)
    if type(label) ~= "string" then
        return nil
    end
    -- Die Muster der Tabelle sind deutsch: den Anzeigetext (evtl. englisch) zurueckuebersetzen.
    label = GTC.Untranslate(label)
    for _, entry in ipairs(BUTTON_TIPS) do
        if label:find(entry[1]) then
            return entry
        end
    end
    return nil
end

local function Button(parent, label, width, height)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    local tipEntry = FindButtonTip(label)
    if tipEntry then
        AddTooltip(b, tipEntry[2], tipEntry[3])
    end
    b:SetSize(width, height)
    b:SetText(label)

    -- Neutrale Flaechen statt des festen roten Blizzard-Button-Stils.
    b:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    b:SetPushedTexture("Interface\\Buttons\\WHITE8X8")
    b:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    b:SetDisabledTexture("Interface\\Buttons\\WHITE8X8")

    local normal = b:GetNormalTexture()
    if normal then
        normal:SetVertexColor(unpack(C.button))
    end

    local pushed = b:GetPushedTexture()
    if pushed then
        pushed:SetVertexColor(unpack(C.buttonPressed))
    end

    local highlight = b:GetHighlightTexture()
    if highlight then
        highlight:SetVertexColor(unpack(C.buttonHover))
    end

    local disabled = b:GetDisabledTexture()
    if disabled then
        disabled:SetVertexColor(unpack(C.buttonDisabled))
    end

    local labelText = b:GetFontString()
    if labelText then
        labelText:SetTextColor(unpack(C.buttonText))
    end

    -- Theme-abhaengiger, klarer Rahmen.
    local top = b:CreateTexture(nil, "OVERLAY")
    top:SetColorTexture(unpack(C.buttonBorder))
    top:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    top:SetHeight(1)

    local bottom = b:CreateTexture(nil, "OVERLAY")
    bottom:SetColorTexture(unpack(C.buttonBorder))
    bottom:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)

    local left = b:CreateTexture(nil, "OVERLAY")
    left:SetColorTexture(unpack(C.buttonBorder))
    left:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)

    local right = b:CreateTexture(nil, "OVERLAY")
    right:SetColorTexture(unpack(C.buttonBorder))
    right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)

    return b
end

local function Text(parent, template, point, relative, relativePoint, x, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetPoint(point, relative, relativePoint, x, y)
    fs:SetTextColor(unpack(C.text))
    return fs
end

local function Backdrop(frame, color, borderColor)
    frame:SetBackdrop({
        bgFile = "Interface/Buttons/WHITE8X8",
        edgeFile = "Interface/Buttons/WHITE8X8",
        edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })
    frame:SetBackdropColor(unpack(color))
    frame:SetBackdropBorderColor(unpack(borderColor or C.gold))
end

local function StyleEditBox(box)
    -- InputBoxTemplate besitzt eigene Left/Middle/Right-Texturen.
    -- SetBackdrop nur aufrufen, wenn die Methode verfuegbar ist.
    if type(box.SetBackdrop) == "function" then
        Backdrop(box, C.inputBackground, C.inputBorder)
    else
        if box.Left then
            box.Left:SetVertexColor(unpack(C.inputBorder))
        end

        if box.Middle then
            box.Middle:SetVertexColor(unpack(C.inputBackground))
        end

        if box.Right then
            box.Right:SetVertexColor(unpack(C.inputBorder))
        end
    end

    box:SetFontObject(GameFontHighlight)
    box:SetTextColor(unpack(C.text))
    box:SetTextInsets(8, 8, 0, 0)
end
local function EnsureData()
    GuildTradeCenterDB = GuildTradeCenterDB or {}
end

-- Fasst viele Aktualisierungswuensche (z. B. hunderte Item-Ladeereignisse nach einem
-- Katalog-Abruf) zu EINEM Aufruf zusammen. Vorher baute jedes einzelne Ereignis den
-- kompletten Katalog (bis 20.000 Eintraege inkl. Sortierung) und die Liste neu auf.
local scheduledRefreshes = {}
local function ScheduleRefresh(key, delay, callback)
    if scheduledRefreshes[key] then
        return
    end
    scheduledRefreshes[key] = true
    local function Run()
        scheduledRefreshes[key] = nil
        local ok, err = pcall(callback)
        if not ok and type(geterrorhandler) == "function" then
            geterrorhandler()(err)
        end
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(delay, Run)
    else
        Run()
    end
end
GTC.ScheduleUIRefresh = ScheduleRefresh

-- Gemeinsame Bausteine (Theme, Buttons, Rahmen) fuer Module wie Recipes.lua.
GTC.UIKit = {
    Button = Button,
    Text = Text,
    Backdrop = Backdrop,
    StyleEditBox = StyleEditBox,
    Theme = function() return C end,
    Tooltip = AddTooltip,
}

function GTC:CreateMainWindow()
    if self.mainWindow then return end
    EnsureData()
    LoadActiveTheme()

    -- GTC_UPDATE3_SEARCH_QUALITY
    -- Laufzeit-Zustand bleibt nur im Addon-Memory; SavedVariables werden nicht veraendert.
    GTC._update3State = GTC._update3State or {
        listing = { search = "", trade = "all", status = "all", ownOnly = false, qualities = {} },
        catalogQualities = {},
        pendingQualityRequests = {},
    }
    local U3 = GTC._update3State
    U3.listing = U3.listing or { search = "", trade = "all", status = "all", ownOnly = false, qualities = {} }
    U3.listing.qualities = U3.listing.qualities or {}
    U3.catalogQualities = U3.catalogQualities or {}
    U3.pendingQualityRequests = U3.pendingQualityRequests or {}
    U3.qualityOptions = {
        { id = 0, label = L("Minderwertig"), color = { 0.62, 0.62, 0.62 } },
        { id = 1, label = L("Gewöhnlich"), color = { 1.00, 1.00, 1.00 } },
        { id = 2, label = L("Ungewöhnlich"), color = { 0.12, 1.00, 0.00 } },
        { id = 3, label = L("Selten"), color = { 0.00, 0.44, 0.87 } },
        { id = 4, label = L("Episch"), color = { 0.64, 0.21, 0.93 } },
        { id = 5, label = L("Legendär"), color = { 1.00, 0.50, 0.00 } },
    }

    -- GTC_UPDATE3_REMOVE_QUALITY_OPTIONS: entfernte Qualitaeten duerfen nicht als versteckte Filter aktiv bleiben.
    if type(U3.listing.qualities) == "table" then
        U3.listing.qualities[6] = nil
        U3.listing.qualities[7] = nil
        U3.listing.qualities[8] = nil
    end
    if type(U3.catalogQualities) == "table" then
        U3.catalogQualities[6] = nil
        U3.catalogQualities[7] = nil
        U3.catalogQualities[8] = nil
    end

    U3.GetItemQuality = U3.GetItemQuality or function(itemID)
        itemID = tonumber(itemID)
        if not itemID then return nil end
        local key = tostring(itemID)
        local db = GTC and GTC.db
        local record = db and type(db.items) == "table" and db.items[key] or nil
        if type(record) == "table" then
            local savedQuality = tonumber(record.quality)
            if savedQuality ~= nil then return savedQuality end
        end
        if C_Item and type(C_Item.GetItemInfo) == "function" then
            local ok, itemName, itemLink, quality = pcall(C_Item.GetItemInfo, itemID)
            if ok and type(quality) == "number" then return quality end
            if type(C_Item.RequestLoadItemDataByID) == "function" and not U3.pendingQualityRequests[key] then
                U3.pendingQualityRequests[key] = true
                local requestOK = pcall(C_Item.RequestLoadItemDataByID, itemID)
                if not requestOK then U3.pendingQualityRequests[key] = nil end
            end
        end
        return nil
    end

    U3.QualityMatches = U3.QualityMatches or function(selected, itemID)
        if type(selected) ~= "table" or next(selected) == nil then return true end
        local quality = U3.GetItemQuality(itemID)
        return quality ~= nil and selected[quality] == true
    end

    U3.AttachQualityMenu = U3.AttachQualityMenu or function(parent, button, selected, onChanged)
        local popup = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        popup:SetSize(184, 216)
        popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        popup:SetFrameStrata("DIALOG")
        popup:SetFrameLevel(math.max(parent:GetFrameLevel(), button:GetFrameLevel()) + 30)
        popup:SetClampedToScreen(true)
        Backdrop(popup, C.panel, C.gold)
        popup:Hide()

        local title = Text(popup, "GameFontNormal", "TOPLEFT", popup, "TOPLEFT", 10, -10)
        title:SetText(L("Itemqualität auswählen"))
        title:SetTextColor(unpack(C.gold))
        local checks = {}

        local function RefreshControls()
            local count = 0
            for id, enabled in pairs(selected) do
                if enabled then count = count + 1 end
            end
            button:SetText(count > 0 and (L("Qualität (") .. tostring(count) .. ")") or L("Qualität"))
            for _, option in ipairs(U3.qualityOptions) do
                if checks[option.id] then checks[option.id]:SetChecked(selected[option.id] == true) end
            end
        end

        for index, optionValue in ipairs(U3.qualityOptions) do
            local option = optionValue
            local check = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
            check:SetSize(22, 22)
            check:SetPoint("TOPLEFT", popup, "TOPLEFT", 7, -30 - ((index - 1) * 23))
            check:SetChecked(selected[option.id] == true)
            local label = popup:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            label:SetPoint("LEFT", check, "RIGHT", 1, 0)
            label:SetJustifyH("LEFT")
            label:SetText(option.label)
            label:SetTextColor(option.color[1], option.color[2], option.color[3])
            check:SetScript("OnClick", function(widget)
                if widget:GetChecked() then selected[option.id] = true else selected[option.id] = nil end
                RefreshControls()
                if type(onChanged) == "function" then onChanged() end
            end)
            checks[option.id] = check
        end

        local reset = Button(popup, L("Alle"), 76, 24)
        reset:SetPoint("BOTTOMLEFT", popup, "BOTTOMLEFT", 8, 7)
        reset:SetScript("OnClick", function()
            for key in pairs(selected) do selected[key] = nil end
            RefreshControls()
            if type(onChanged) == "function" then onChanged() end
        end)
        local close = Button(popup, L("Fertig"), 76, 24)
        close:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -8, 7)
        close:SetScript("OnClick", function() popup:Hide() end)

        button:SetScript("OnClick", function()
            if popup:IsShown() then popup:Hide() else RefreshControls(); popup:Show() end
        end)
        RefreshControls()
        return { popup = popup, refresh = RefreshControls }
    end

    U3.AttachChoiceMenu = U3.AttachChoiceMenu or function(parent, button, state, stateKey, caption, options, onChanged)
        local popup = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        popup:SetSize(142, (#options * 25) + 16)
        popup:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
        popup:SetFrameStrata("DIALOG")
        popup:SetFrameLevel(math.max(parent:GetFrameLevel(), button:GetFrameLevel()) + 30)
        popup:SetClampedToScreen(true)
        Backdrop(popup, C.panel, C.gold)
        popup:Hide()

        local function RefreshLabel()
            local value = state[stateKey] or "all"
            for _, choice in ipairs(options) do
                if choice.value == value then
                    button:SetText(caption .. ": " .. choice.short)
                    return
                end
            end
            button:SetText(caption .. L(": Alle"))
        end

        for index, choiceValue in ipairs(options) do
            local choice = choiceValue
            local optionButton = Button(popup, choice.label, 130, 23)
            AddTooltip(optionButton, choice.label, L("Setzt den Filter auf diese Auswahl."))
            optionButton:SetPoint("TOPLEFT", popup, "TOPLEFT", 6, -6 - ((index - 1) * 25))
            optionButton:SetScript("OnClick", function()
                state[stateKey] = choice.value
                RefreshLabel()
                popup:Hide()
                if type(onChanged) == "function" then onChanged() end
            end)
        end

        button:SetScript("OnClick", function()
            if popup:IsShown() then popup:Hide() else RefreshLabel(); popup:Show() end
        end)
        RefreshLabel()
        return { popup = popup, refresh = RefreshLabel }
    end

    local root = CreateFrame(
        "Frame", "GuildTradeCenterMainWindow", UIParent,
        "BasicFrameTemplateWithInset"
    )
    root:SetSize(900, 700)
    root:SetPoint("CENTER")
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", root.StartMoving)
    root:SetScript("OnDragStop", root.StopMovingOrSizing)
    root:SetClampedToScreen(true)
    root:Hide()
    root.TitleText:SetText("GuildTradeCenter")

    local background = CreateFrame("Frame", nil, root, "BackdropTemplate")
    background:SetPoint("TOPLEFT", root, "TOPLEFT", 8, -28)
    background:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -8, 8)
    Backdrop(background, C.panel, C.gold)
    background:SetFrameLevel(root:GetFrameLevel())

    -- GTC-Logo im Kopfbereich des Handelsbretts
    local headerLogo = root:CreateTexture(nil, "ARTWORK")
    headerLogo:SetTexture("Interface\\AddOns\\GuildTradeCenter\\GTC_Logo_512.png")
    headerLogo:SetSize(34, 34)
    headerLogo:SetPoint("TOPLEFT", root, "TOPLEFT", 22, -32)

    local title = Text(root, "GameFontNormalLarge", "LEFT", headerLogo, "RIGHT", 8, 0)
    title:SetText(L("Gilden-Handelsbrett"))
    title:SetTextColor(unpack(C.gold))

    local status = Text(root, "GameFontHighlightSmall", "TOPRIGHT", root, "TOPRIGHT", -25, -42)
    status:SetText(string.format("|cff%02x%02x%02xGTC v%s|r", math.floor(C.cyan[1] * 255), math.floor(C.cyan[2] * 255), math.floor(C.cyan[3] * 255), tostring(GTC.version or "unbekannt")))

    local offers = Button(root, L("Angebote"), 100, 30)
    offers:SetPoint("TOPLEFT", root, "TOPLEFT", 22, -72)

    local wanted = Button(root, L("Gesuche"), 100, 30)
    wanted:SetPoint("LEFT", offers, "RIGHT", 8, 0)

    local recipesButton = Button(root, L("Rezepte"), 100, 30)
    recipesButton:SetPoint("LEFT", wanted, "RIGHT", 8, 0)

    local createEntry = Button(root, L("Eintrag erstellen"), 135, 30)
    createEntry:SetPoint("LEFT", recipesButton, "RIGHT", 8, 0)

    local scanButton = Button(root, L("Scannen"), 84, 30)
    scanButton:SetPoint("LEFT", createEntry, "RIGHT", 8, 0)

    local syncButton = Button(root, L("Sync"), 60, 30)
    syncButton:SetPoint("LEFT", scanButton, "RIGHT", 8, 0)
    AddTooltip(syncButton, L("Sync"), L("Sendet deine Inserate erneut an die Gilde und fragt Neuigkeiten ab (alle 60 s möglich). Status: /gtcsync status"))
    syncButton:SetScript("OnClick", function()
        if type(GTC.ManualSync) == "function" then
            GTC:ManualSync()
        end
    end)

    local syncStatusText = Text(
        root, "GameFontHighlightSmall", "LEFT", syncButton, "RIGHT", 8, 0
    )
    syncStatusText:SetWidth(100)
    syncStatusText:SetJustifyH("LEFT")
    syncStatusText:SetWordWrap(false)
    syncStatusText:SetText(self.windowStatusMessage or L("Sync: bereit"))

    self.syncStatusText = syncStatusText
-- Auswahl des UI-Themes. Die Handelsdaten bleiben davon unberuehrt.
    local themePicker = Button(root, L("Design: ") .. C.label, 130, 30)
    themePicker:SetPoint("TOPRIGHT", root, "TOPRIGHT", -18, -72)

    local themeMenu = CreateFrame("Frame", nil, root, "BackdropTemplate")
    themeMenu:SetSize(164, 104)
    themeMenu:SetPoint("TOPRIGHT", themePicker, "BOTTOMRIGHT", 0, -2)
    themeMenu:SetFrameStrata("DIALOG")
    themeMenu:SetFrameLevel(root:GetFrameLevel() + 20)
    Backdrop(themeMenu, C.panel, C.gold)
    themeMenu:Hide()

    local function RequestThemeChange(requestedTheme)
        if not THEMES[requestedTheme] or requestedTheme == activeThemeKey then
            return
        end

        StaticPopupDialogs["GTC_THEME_APPLY"] = {
            text = L("Das Design wird direkt angewendet. Das GTC-Fenster wird neu aufgebaut. Ungespeicherte Formular-Eingaben gehen verloren. Fortfahren?"),
            button1 = L("Design anwenden"),
            button2 = L("Abbrechen"),
            OnAccept = function()
                local wasShown = root:IsShown()

                -- Nur die Theme-Einstellung speichern.
                -- Die Handelsdaten bleiben unveraendert.
                EnsureData()
                GuildTradeCenterDB.theme = requestedTheme

                -- Aktive Palette fuer alle neu erstellten Elemente wechseln.
                activeThemeKey = requestedTheme
                C = THEMES[requestedTheme]

                -- Alte Eingabefeld-Referenzen nicht weiterverwenden.
                GTC.itemLinkCaptureActive = false
                GTC.itemLinkTarget = nil
                GTC.descriptionLinkTarget = nil

                -- Altes Fenster ausblenden und seine globalen Namen freigeben.
                root:Hide()

                local function ClearNamedFrameReferences(frame)
                    local children = { frame:GetChildren() }

                    for _, child in ipairs(children) do
                        ClearNamedFrameReferences(child)
                    end

                    local regions = { frame:GetRegions() }

                    for _, region in ipairs(regions) do
                        if region and type(region.GetName) == "function" then
                            local regionName = region:GetName()

                            if regionName and _G[regionName] == region then
                                _G[regionName] = nil
                            end
                        end
                    end

                    local frameName = frame:GetName()

                    if frameName and _G[frameName] == frame then
                        _G[frameName] = nil
                    end
                end

                ClearNamedFrameReferences(root)
                root:SetParent(nil)

                if self.mainWindow == root then
                    self.mainWindow = nil
                end

                self.syncStatusText = nil

                -- Nur das GTC-Fenster neu erzeugen.
                self:CreateMainWindow()

                if wasShown and self.mainWindow then
                    self.mainWindow:Show()
                end
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }

        StaticPopup_Show("GTC_THEME_APPLY")
    end

    local themeOptions = {"dark", "azeroth", "clean"}

    for index, themeOptionKey in ipairs(themeOptions) do
        local optionKey = themeOptionKey
        local themeOption = Button(themeMenu, THEMES[optionKey].label, 146, 24)
        AddTooltip(themeOption, THEMES[optionKey].label, L("Wendet dieses Design an. Das Fenster wird neu aufgebaut."))
        themeOption:SetPoint(
            "TOPLEFT", themeMenu, "TOPLEFT",
            9, -7 - ((index - 1) * 30)
        )

        themeOption:SetScript("OnClick", function()
            themeMenu:Hide()
            RequestThemeChange(optionKey)
        end)
    end

    themePicker:SetScript("OnClick", function()
        if themeMenu:IsShown() then
            themeMenu:Hide()
        else
            themeMenu:Show()
        end
    end)

    function GTC:SetWindowStatus(message)
        self.windowStatusMessage = tostring(message or "")
        if self.syncStatusText and self.syncStatusText.SetText then
            self.syncStatusText:SetText(self.windowStatusMessage)
        end
    end

    scanButton:SetScript("OnClick", function()
        if type(GTC.StartInventoryScan) ~= "function" then
            GTC:SetWindowStatus(L("Scanner nicht verfügbar"))
            return
        end

        scanButton:SetEnabled(false)
        scanButton:SetText("Scan 0%")

        local started, reason = GTC:StartInventoryScan(
            function(processed, total, newItems, includeBank)
                local percent = total > 0
                    and math.floor((processed / total) * 100) or 100

                scanButton:SetText("Scan " .. percent .. "%")
                GTC:SetWindowStatus(
                    (includeBank and L("Taschen + Bank: ") or L("Taschen: ")) ..
                    percent .. "% (" .. processed .. "/" .. total .. ")"
                )
            end,
            function(ok, newItems, visited, message, includeBank)
                scanButton:SetEnabled(true)
                scanButton:SetText(L("Scannen"))

                if ok then
                    GTC:SetWindowStatus(
                        L("Scan fertig: ") .. newItems .. L(" neue Items") ..
                        (includeBank and L(" (Taschen + Bank)") or L(" (Taschen)"))
                    )
                else
                    GTC:SetWindowStatus(L("Scan fehlgeschlagen: ") ..
                        tostring(message or L("Unbekannter Fehler")))
                end
            end
        )

        if not started then
            scanButton:SetEnabled(true)
            scanButton:SetText(L("Scannen"))
            GTC:SetWindowStatus(L("Scan nicht gestartet: ") .. tostring(reason))
        end
    end)

    local listPanel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    listPanel:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -112)
    listPanel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 48)
    Backdrop(listPanel, C.listPanel, C.border)

    local listTitle = Text(listPanel, "GameFontNormal", "TOPLEFT", listPanel, "TOPLEFT", 16, -14)
    local pageLabel = Text(listPanel, "GameFontHighlightSmall", "TOPRIGHT", listPanel, "TOPRIGHT", -16, -15)

    do
        local function RefreshListingFilters()
            GTC.currentPage = 1
            if type(GTC.RefreshListingView) == "function" then GTC:RefreshListingView() end
        end

        local listingSearchBox = CreateFrame("EditBox", nil, listPanel, "InputBoxTemplate")
        StyleEditBox(listingSearchBox)
        listingSearchBox:SetSize(255, 24)
        listingSearchBox:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 12, -36)
        listingSearchBox:SetAutoFocus(false)
        listingSearchBox:SetMaxLetters(180)
        listingSearchBox:SetText(U3.listing.search or "")

        local searchHint = listPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        searchHint:SetPoint("LEFT", listingSearchBox, "LEFT", 8, 0)
        searchHint:SetJustifyH("LEFT")
        searchHint:SetText(L("Item, ID, Charakter, Beschreibung"))
        searchHint:SetTextColor(unpack(C.muted))
        searchHint:SetShown((listingSearchBox:GetText() or "") == "")

        local function UpdateSearchHint()
            searchHint:SetShown((listingSearchBox:GetText() or "") == "" and not listingSearchBox:HasFocus())
        end
        listingSearchBox:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
        listingSearchBox:SetScript("OnEditFocusLost", UpdateSearchHint)
        listingSearchBox:SetScript("OnTextChanged", function(box)
            U3.listing.search = (box:GetText() or ""):lower()
            UpdateSearchHint()
            -- Beim Tippen nicht nach jedem Buchstaben die ganze Liste filtern.
            ScheduleRefresh("listingSearch", 0.15, RefreshListingFilters)
        end)

        local tradeButton = Button(listPanel, L("Handel: Alle"), 108, 24)
        tradeButton:SetPoint("LEFT", listingSearchBox, "RIGHT", 6, 0)
        local tradeControls = U3.AttachChoiceMenu(listPanel, tradeButton, U3.listing, "trade", L("Handel"), {
            { value = "all", label = L("Alle Handelsarten"), short = L("Alle") },
            { value = "Tausch", label = L("Tausch"), short = L("Tausch") },
            { value = "Verkauf", label = L("Verkauf"), short = L("Verkauf") },
            { value = "Kostenlos", label = L("Kostenlos"), short = L("Gratis") },
            { value = "Kaufe", label = L("Kaufe"), short = L("Kaufe") },
        }, RefreshListingFilters)

        local statusButton = Button(listPanel, L("Status: Alle"), 98, 24)
        statusButton:SetPoint("LEFT", tradeButton, "RIGHT", 6, 0)
        local statusControls = U3.AttachChoiceMenu(listPanel, statusButton, U3.listing, "status", "Status", {
            { value = "all", label = L("Alle Status"), short = L("Alle") },
            { value = "active", label = L("Aktiv"), short = L("Aktiv") },
            { value = "completed", label = L("Abgeschlossen"), short = L("Fertig") },
        }, RefreshListingFilters)

        local listingQualityButton = Button(listPanel, L("Qualität"), 94, 24)
        listingQualityButton:SetPoint("LEFT", statusButton, "RIGHT", 6, 0)
        local listingQualityControls = U3.AttachQualityMenu(listPanel, listingQualityButton, U3.listing.qualities, RefreshListingFilters)

        local ownOnlyCheck = CreateFrame("CheckButton", nil, listPanel, "UICheckButtonTemplate")
        ownOnlyCheck:SetSize(22, 22)
        ownOnlyCheck:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -9, -36)
        ownOnlyCheck:SetChecked(U3.listing.ownOnly == true)
        local ownOnlyLabel = listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        ownOnlyLabel:SetPoint("RIGHT", ownOnlyCheck, "LEFT", -2, 0)
        ownOnlyLabel:SetWidth(82)
        ownOnlyLabel:SetJustifyH("RIGHT")
        ownOnlyLabel:SetText(L("Nur eigene"))
        ownOnlyLabel:SetTextColor(unpack(C.text))
        local showOwnOnly = GTC.db and GTC.db.scopeType == "guild"
        ownOnlyCheck:SetShown(showOwnOnly == true)
        ownOnlyLabel:SetShown(showOwnOnly == true)
        ownOnlyCheck:SetScript("OnClick", function(widget)
            U3.listing.ownOnly = widget:GetChecked() == true
            RefreshListingFilters()
        end)

        AddTooltip(ownOnlyCheck, L("Nur eigene"), L("Zeigt nur Einträge deiner eigenen Charaktere."))

        local resetFiltersButton = Button(listPanel, "Reset", 72, 24)
        resetFiltersButton:SetPoint("TOPRIGHT", listPanel, "TOPRIGHT", -130, -36)
        resetFiltersButton:SetScript("OnClick", function()
            U3.listing.search = ""
            U3.listing.trade = "all"
            U3.listing.status = "all"
            U3.listing.ownOnly = false
            for key in pairs(U3.listing.qualities) do U3.listing.qualities[key] = nil end
            listingSearchBox:SetText("")
            ownOnlyCheck:SetChecked(false)
            tradeControls.refresh()
            statusControls.refresh()
            listingQualityControls.refresh()
            RefreshListingFilters()
        end)

        U3.listingControls = {
            searchBox = listingSearchBox,
            trade = tradeControls,
            status = statusControls,
            quality = listingQualityControls,
            ownOnly = ownOnlyCheck,
        }
    end

    local rows = {}
    local emptyMessage = Text(listPanel, "GameFontHighlight", "CENTER", listPanel, "CENTER", 0, -10)
    emptyMessage:SetText(L("Noch keine Einträge vorhanden."))
    emptyMessage:SetTextColor(unpack(C.muted))
    emptyMessage:Hide()

    -- v1.1.7: Berufs-Inserate ([Schmiedekunst] usw., Professions.lua).
    local Prof = GTC.Prof
    local function EntryProf(entry)
        return Prof and Prof:EntryProfession(entry) or nil
    end

    local function FindListingById(id)
        for _, listing in ipairs((GTC.db and GTC.db.listings) or {}) do
            if type(listing) == "table" and listing.id == id then
                return listing
            end
        end
        return nil
    end

    -- Angebot: Rezepte des Erstellers zeigen. Gesuch: alle Handwerker der Gilde in dem Beruf.
    local function OpenProfessionEntry(entry)
        local pid = EntryProf(entry)
        if not pid then return end
        if entry.kind == "wanted" then
            if type(GTC.ShowProfessionRecipes) == "function" then
                GTC:ShowProfessionRecipes(pid)
            end
            return
        end
        local id = entry.id
        Prof:ShowRecipes(entry, function()
            local current = FindListingById(id) or entry
            if GTC._gtcOpenListing then GTC._gtcOpenListing(current) end
        end)
    end

    local detail = CreateFrame("Frame", nil, root, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -112)
    detail:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 48)
    Backdrop(detail, C.detailPanel, C.gold)
    detail:Hide()

    -- WoW-Hyperlinks in Titel und Beschreibung aktivieren.
    detail:SetHyperlinksEnabled(true)
    detail:SetScript("OnHyperlinkClick", function(self, link, text, button)
        if type(link) == "string" and link:match("^gtcprof:") then
            OpenProfessionEntry(GTC.currentDetailEntry)
            return
        end
        if type(ChatFrame_OnHyperlinkShow) == "function" then
            ChatFrame_OnHyperlinkShow(self, link, text, button)
        elseif type(SetItemRef) == "function" then
            SetItemRef(link, text, button, self)
        end
    end)

    detail:SetScript("OnHyperlinkEnter", function(self, link, text)
        if type(link) == "string" and link:match("^gtcprof:") then
            local entry = GTC.currentDetailEntry
            if EntryProf(entry) then
                GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
                Prof:FillTooltip(GameTooltip, entry)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(entry.kind == "wanted" and L("Klick: Handwerker in der Gilde anzeigen")
                    or L("Klick: alle Rezepte anzeigen"), 0.2, 0.85, 0.85)
                GameTooltip:Show()
            end
            return
        end
        if type(ChatFrame_OnHyperlinkEnter) == "function" then
            ChatFrame_OnHyperlinkEnter(self, link, text)
        elseif type(link) == "string" and link:match("^item:") then
            GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end
    end)

    detail:SetScript("OnHyperlinkLeave", function(self, link, text)
        if type(ChatFrame_OnHyperlinkLeave) == "function" then
            ChatFrame_OnHyperlinkLeave(self, link, text)
        else
            GameTooltip:Hide()
        end
    end)

    local detailTitle = Text(detail, "GameFontNormalLarge", "TOPLEFT", detail, "TOPLEFT", 22, -25)
    detailTitle:SetTextColor(unpack(C.gold))

    local detailType = Text(detail, "GameFontNormal", "TOPLEFT", detail, "TOPLEFT", 22, -65)
    detailType:SetTextColor(unpack(C.cyan))

    local detailQty = Text(detail, "GameFontHighlight", "TOPLEFT", detail, "TOPLEFT", 22, -96)
    local detailCharacterLabel = Text(detail, "GameFontHighlight", "TOPLEFT", detail, "TOPLEFT", 22, -124)
    detailCharacterLabel:SetText(L("Charakter:"))

    local detailCharacter = CreateFrame("Button", nil, detail)
    detailCharacter:SetSize(420, 28)
    detailCharacter:SetPoint("TOPLEFT", detail, "TOPLEFT", 100, -116)
    detailCharacter:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    -- Feste Box: alle Texturen bleiben innerhalb des Charakter-Buttons.
    local characterBoxBackground = detailCharacter:CreateTexture(nil, "BACKGROUND")
    characterBoxBackground:SetAllPoints(detailCharacter)
    characterBoxBackground:SetColorTexture(unpack(C.characterBackground))

    -- Diese Textur wird ausschliesslich beim Hover eingeblendet.
    local characterHighlight = detailCharacter:CreateTexture(nil, "ARTWORK")
    characterHighlight:SetAllPoints(detailCharacter)
    characterHighlight:SetColorTexture(unpack(C.characterHover))
    characterHighlight:Hide()

    -- Klar sichtbarer, auf die Box begrenzter Rahmen.
    local function CreateCharacterBorder()
        local texture = detailCharacter:CreateTexture(nil, "OVERLAY")
        texture:SetColorTexture(unpack(C.characterBorder))
        return texture
    end

    local characterBorderTop = CreateCharacterBorder()
    characterBorderTop:SetPoint("TOPLEFT", detailCharacter, "TOPLEFT", 0, 0)
    characterBorderTop:SetPoint("TOPRIGHT", detailCharacter, "TOPRIGHT", 0, 0)
    characterBorderTop:SetHeight(1)

    local characterBorderBottom = CreateCharacterBorder()
    characterBorderBottom:SetPoint("BOTTOMLEFT", detailCharacter, "BOTTOMLEFT", 0, 0)
    characterBorderBottom:SetPoint("BOTTOMRIGHT", detailCharacter, "BOTTOMRIGHT", 0, 0)
    characterBorderBottom:SetHeight(1)

    local characterBorderLeft = CreateCharacterBorder()
    characterBorderLeft:SetPoint("TOPLEFT", detailCharacter, "TOPLEFT", 0, 0)
    characterBorderLeft:SetPoint("BOTTOMLEFT", detailCharacter, "BOTTOMLEFT", 0, 0)
    characterBorderLeft:SetWidth(1)

    local characterBorderRight = CreateCharacterBorder()
    characterBorderRight:SetPoint("TOPRIGHT", detailCharacter, "TOPRIGHT", 0, 0)
    characterBorderRight:SetPoint("BOTTOMRIGHT", detailCharacter, "BOTTOMRIGHT", 0, 0)
    characterBorderRight:SetWidth(1)

    local characterNameText = detailCharacter:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    characterNameText:SetPoint("LEFT", detailCharacter, "LEFT", 8, 0)
    characterNameText:SetJustifyH("LEFT")
    characterNameText:SetTextColor(unpack(C.cyan))


    local descLabel = Text(detail, "GameFontNormal", "TOPLEFT", detail, "TOPLEFT", 22, -166)
    descLabel:SetText(L("BESCHREIBUNG"))
    descLabel:SetTextColor(unpack(C.gold))

    local detailDescription = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    detailDescription:SetPoint("TOPLEFT", detail, "TOPLEFT", 22, -190)
    detailDescription:SetPoint("RIGHT", detail, "RIGHT", -22, 0)
    detailDescription:SetJustifyH("LEFT")
    detailDescription:SetJustifyV("TOP")
    detailDescription:SetWordWrap(true)

    local back = Button(detail, L("< Zurück zur Liste"), 160, 28)
    back:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", 18, 16)
    back:SetScript("OnClick", function()
        detail:Hide()
        listPanel:Show()
    end)


    -- Wunschliste: Item beobachten und im Chat benachrichtigt werden (Watchlist.lua).
    local watchButton = Button(detail, L("Beobachten"), 150, 28)
    watchButton:SetPoint("LEFT", back, "RIGHT", 8, 0)
    AddTooltip(watchButton, L("Wunschliste"), L("Meldet im Chat, wenn ein Gildenmitglied dieses Item neu einstellt."))

    local function RefreshWatchButton(entry)
        local itemID = entry and tonumber(entry.itemID)
        if not itemID or EntryProf(entry) or type(GTC.WatchHas) ~= "function" then
            watchButton:Hide()
            return
        end
        watchButton:SetText(GTC:WatchHas(itemID) and L("Nicht beobachten") or L("Beobachten"))
        watchButton:Show()
    end

    watchButton:SetScript("OnClick", function()
        local entry = self.currentDetailEntry
        local itemID = entry and tonumber(entry.itemID)
        if not itemID or type(GTC.WatchToggle) ~= "function" then return end
        local ok, _, message = GTC:WatchToggle(itemID, entry.item)
        if not ok and message then
            GTC:Print(message)
        end
        RefreshWatchButton(entry)
    end)

    local editEntryButton = Button(detail, L("Bearbeiten"), 110, 28)
    editEntryButton:SetPoint("BOTTOMRIGHT", detail, "BOTTOMRIGHT", -18, 16)
    editEntryButton:Hide()

    local deleteEntryButton = Button(detail, L("Löschen"), 110, 28)
    deleteEntryButton:SetPoint("RIGHT", editEntryButton, "LEFT", -8, 0)
    deleteEntryButton:Hide()

    local completeEntryButton = Button(detail, L("Abgeschlossen"), 130, 28)
    AddTooltip(completeEntryButton, L("Eintrag abschließen"), L("Markiert deinen Eintrag als erledigt. Er bleibt sichtbar, kann aber nicht mehr bearbeitet werden."))
    completeEntryButton:SetPoint("RIGHT", deleteEntryButton, "LEFT", -8, 0)
    completeEntryButton:Hide()

    -- Berufs-Inserat: Rezepte ansehen bzw. natives Berufsfenster oeffnen.
    local profRecipesButton = Button(detail, L("Rezepte ansehen"), 190, 28)
    profRecipesButton:SetPoint("TOPRIGHT", detail, "TOPRIGHT", -22, -60)
    profRecipesButton:Hide()
    profRecipesButton:SetScript("OnClick", function()
        OpenProfessionEntry(self.currentDetailEntry)
    end)
    AddTooltip(profRecipesButton, L("Rezepte ansehen"), L("Öffnet den Reiter Rezepte mit allen Rezepten, die der Handwerker in diesem Beruf kennt. Funktioniert auch, wenn er offline ist."))

    local profNativeButton = Button(detail, L("Berufsfenster öffnen"), 190, 28)
    profNativeButton:SetPoint("TOP", profRecipesButton, "BOTTOM", 0, -6)
    profNativeButton:Hide()
    profNativeButton:SetScript("OnClick", function(button)
        if not (Prof and Prof:OpenNative(self.currentDetailEntry, button)) then
            GTC:Print(L("Das Berufsfenster konnte nicht geöffnet werden."))
        end
    end)
    AddTooltip(profNativeButton, L("Berufsfenster öffnen"), L("Öffnet den Berufs-Link des Spiels (Blizzard-Fenster). Je nach Server nur möglich, solange der Handwerker online ist."))

    local function ContactCurrentEntry()
        local entry = self.currentDetailEntry
        if not entry then
            self:Print(L("Kein Angebot ausgewählt."))
            return
        end

        -- Diese Ansicht zeigt aktuell ausschliesslich lokale Testeintraege.
        -- Erst echte Eintraege duerfen einen Kontakt ausloesen.
        if entry.isTest ~= false then
            self:Print(L("Testcharakter: Ein echter Whisper ist mit Beispieldaten nicht möglich."))
            return
        end

        local name = entry.character
        if not name or name == "" then
            self:Print(L("Kein Charaktername hinterlegt."))
            return
        end

        if type(ChatFrame_SendTell) == "function" then
            ChatFrame_SendTell(name)
        else
            self:Print(L("Die Whisper-Funktion ist in diesem Client nicht verfügbar."))
        end
    end


    detailCharacter:SetScript("OnEnter", function()
        characterHighlight:Show()
        GameTooltip:SetOwner(detailCharacter, "ANCHOR_RIGHT")
        GameTooltip:SetText(L("Spieler: ") .. tostring(self.currentDetailEntry and self.currentDetailEntry.character or L("Unbekannt")))
        GameTooltip:AddLine(L("Linksklick: Whisper"), 0.2, 0.85, 0.85)
        GameTooltip:AddLine(L("Rechtsklick: Spielermenü"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    detailCharacter:SetScript("OnLeave", function()
        characterHighlight:Hide()
        GameTooltip:Hide()
    end)

    detailCharacter:SetScript("OnClick", function(_, mouseButton)
        local entry = self.currentDetailEntry
        if not entry then return end

        if mouseButton == "RightButton" then
            if type(MenuUtil) == "table" and type(MenuUtil.CreateContextMenu) == "function" then
                MenuUtil.CreateContextMenu(detailCharacter, function(_, rootDescription)
                    rootDescription:CreateButton(L("Whisper senden"), function()
                        ContactCurrentEntry()
                    end)
                    rootDescription:CreateButton(L("Charakternamen kopieren"), function()
                        local name = tostring(entry.character or "")
                        if name == "" or name == L("Unbekannt") then
                            GTC:Print(L("Kein gültiger Charaktername vorhanden."))
                            return
                        end

                        local copyFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
                        copyFrame:SetSize(360, 125)
                        copyFrame:SetPoint("CENTER")
                        copyFrame:SetFrameStrata("DIALOG")
                        copyFrame:SetBackdrop({
                            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
                            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
                            tile = true,
                            tileSize = 32,
                            edgeSize = 24,
                            insets = { left = 8, right = 8, top = 8, bottom = 8 }
                        })
                        copyFrame:SetBackdropColor(unpack(C.panel))

                        local title = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        title:SetPoint("TOP", copyFrame, "TOP", 0, -16)
                        title:SetText(L("Charakternamen kopieren"))

                        local editBox = CreateFrame("EditBox", nil, copyFrame, "InputBoxTemplate")
                        StyleEditBox(editBox)
                        editBox:SetSize(280, 24)
                        editBox:SetPoint("TOP", title, "BOTTOM", 0, -14)
                        editBox:SetAutoFocus(false)
                        editBox:SetText(name)
                        editBox:HighlightText()
                        editBox:SetScript("OnEscapePressed", function()
                            copyFrame:Hide()
                        end)
                        editBox:SetScript("OnEnterPressed", function()
                            copyFrame:Hide()
                        end)

                        local hint = copyFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                        hint:SetPoint("BOTTOM", copyFrame, "BOTTOM", 0, 14)
                        hint:SetText(L("Strg+C kopiert den markierten Namen"))

                        copyFrame:Show()
                        editBox:SetFocus()
                        editBox:HighlightText()
                    end)
                end)
            else
                GTC:Print(L("Das Spielermenü ist in diesem Client nicht verfügbar."))
            end
        else
            ContactCurrentEntry()
        end
    end)

    local formPanel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    formPanel:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -112)
    formPanel:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 48)
    Backdrop(formPanel, C.detailPanel, C.gold)
    formPanel:Hide()

    local formTitle = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    formTitle:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 22, -18)
    formTitle:SetText(L("Neuen Eintrag erstellen"))
    formTitle:SetTextColor(unpack(C.gold))

    local formHint = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    formHint:SetPoint("TOPLEFT", formTitle, "BOTTOMLEFT", 0, -8)
    formHint:SetText(L("Item-Link per Shift-Klick einsetzen oder über 'Beruf' einen Beruf wählen (alle Rezepte einsehbar)."))

    local function FormLabel(label, y)
        local text = formPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 24, y)
        text:SetText(label)
        return text
    end

    local function FormInput(width, y, initialText)
        local box = CreateFrame("EditBox", nil, formPanel, "InputBoxTemplate")
        StyleEditBox(box)
        box:SetSize(width, 24)
        box:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 180, y)
        box:SetAutoFocus(false)
        box:EnableMouse(true)
        box:EnableKeyboard(true)
        box:SetText(initialText or "")
        box:SetScript("OnMouseDown", function(editBox)
            editBox:SetFocus()
        end)
        box:SetScript("OnEnterPressed", function(editBox)
            editBox:ClearFocus()
        end)
        box:SetScript("OnEscapePressed", function(editBox)
            editBox:ClearFocus()
        end)
        return box
    end

    FormLabel(L("Item / Beruf:"), -72)
    local itemBox = FormInput(420, -68, "")
    itemBox:SetMaxLetters(500)

    -- Standardziel fuer Item-Links; das Ziel folgt dem aktiven Eingabefeld.
    GTC.itemLinkTarget = itemBox
    itemBox:SetScript("OnEditFocusGained", function()
        GTC.itemLinkTarget = itemBox
    end)

    local catalogButton = Button(formPanel, L("Aus Katalog"), 88, 24)
    catalogButton:SetPoint("LEFT", itemBox, "RIGHT", 8, 0)

    local itemCatalogFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    itemCatalogFrame:SetSize(520, 540)
    itemCatalogFrame:SetPoint("CENTER")
    itemCatalogFrame:SetFrameStrata("DIALOG")
    itemCatalogFrame:SetClampedToScreen(true)
    itemCatalogFrame:SetMovable(true)
    itemCatalogFrame:EnableMouse(true)
    itemCatalogFrame:RegisterForDrag("LeftButton")
    itemCatalogFrame:SetScript("OnDragStart", itemCatalogFrame.StartMoving)
    itemCatalogFrame:SetScript("OnDragStop", itemCatalogFrame.StopMovingOrSizing)
    itemCatalogFrame:Hide()
    Backdrop(itemCatalogFrame, C.panel, C.gold)

    local catalogTitle = itemCatalogFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    catalogTitle:SetPoint("TOPLEFT", itemCatalogFrame, "TOPLEFT", 18, -18)
    catalogTitle:SetText(L("Item aus Katalog auswählen"))
    catalogTitle:SetTextColor(unpack(C.gold))

    local catalogHint = itemCatalogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    catalogHint:SetPoint("TOPLEFT", catalogTitle, "BOTTOMLEFT", 0, -8)
    catalogHint:SetText(L("Suche nach Item-Name oder Item-ID."))

    local catalogSearch = CreateFrame("EditBox", nil, itemCatalogFrame, "InputBoxTemplate")
    StyleEditBox(catalogSearch)
    catalogSearch:SetSize(350, 26)
    catalogSearch:SetPoint("TOPLEFT", itemCatalogFrame, "TOPLEFT", 20, -68)
    catalogSearch:SetAutoFocus(false)
    catalogSearch:SetText("")
    catalogSearch:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        itemCatalogFrame:Hide()
    end)

    local catalogClose = Button(itemCatalogFrame, L("Schließen"), 110, 26)
    catalogClose:SetPoint("BOTTOMRIGHT", itemCatalogFrame, "BOTTOMRIGHT", -18, 14)

    local catalogLoad = Button(itemCatalogFrame, L("Von Gilde laden"), 130, 26)
    catalogLoad:SetPoint("BOTTOMLEFT", itemCatalogFrame, "BOTTOMLEFT", 18, 14)

    local catalogStatus = itemCatalogFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    catalogStatus:SetPoint("LEFT", catalogLoad, "RIGHT", 10, 0)
    catalogStatus:SetPoint("RIGHT", catalogClose, "LEFT", -10, 0)
    catalogStatus:SetJustifyH("LEFT")
    catalogStatus:SetWordWrap(false)
    catalogStatus:SetTextColor(unpack(C.muted))
    catalogClose:SetScript("OnClick", function()
        catalogSearch:ClearFocus()
        itemCatalogFrame:Hide()
    end)

    local catalogScroll = CreateFrame(
        "ScrollFrame", nil, itemCatalogFrame, "UIPanelScrollFrameTemplate"
    )
    catalogScroll:SetPoint("TOPLEFT", itemCatalogFrame, "TOPLEFT", 18, -102)
    catalogScroll:SetPoint("BOTTOMRIGHT", itemCatalogFrame, "BOTTOMRIGHT", -38, 52)

    local catalogContent = CreateFrame("Frame", nil, catalogScroll)
    catalogContent:SetSize(440, 1)
    catalogScroll:SetScrollChild(catalogContent)

    local catalogEmpty = catalogContent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    catalogEmpty:SetPoint("TOP", catalogContent, "TOP", 0, -12)
    catalogEmpty:SetWidth(420)
    catalogEmpty:SetJustifyH("CENTER")
    catalogEmpty:SetText(L("Keine Items im Katalog. Bitte zuerst scannen."))
    catalogEmpty:Show()

    local catalogRows = {}
    local catalogEntries = {}
    local RefreshItemCatalog
    local RenderCatalogRows
    local catalogSearchGeneration = 0

    local function IsValidCatalogLink(link)
        return type(link) == "string"
            and link:match("|[Hh]item:(%d+)") ~= nil
    end

    local function RequestCatalogItemData(itemID)
        if not itemID then return end

        if type(GTC.UpdateItemMetadata) == "function" then
            pcall(GTC.UpdateItemMetadata, GTC, itemID)
        end

        if C_Item and type(C_Item.RequestLoadItemData) == "function" then
            pcall(C_Item.RequestLoadItemData, itemID)
        end
    end

    local function EnsureCatalogRow(index)
        local row = catalogRows[index]
        if row then return row end

        row = CreateFrame("Button", nil, catalogContent, "BackdropTemplate")
        row:SetSize(440, 38)
        Backdrop(row, C.card, C.border)
        AddTooltip(row, L("Item übernehmen"), L("Klicken, um diesen Gegenstand in den Eintrag zu übernehmen."))

        row.iconTexture = row:CreateTexture(nil, "ARTWORK")
        row.iconTexture:SetSize(28, 28)
        row.iconTexture:SetPoint("LEFT", row, "LEFT", 6, 0)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetPoint("LEFT", row.iconTexture, "RIGHT", 8, 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.label:SetJustifyH("LEFT")

        row:SetScript("OnClick", function(button)
            local selected = button.catalogItem
            if type(selected) ~= "table" then return end

            local selectedID = tonumber(selected.itemID)
            if not selectedID and IsValidCatalogLink(selected.itemLink) then
                selectedID = tonumber(selected.itemLink:match("|[Hh]item:(%d+)"))
            end

            if not selectedID then
                ShowGTCItemFeedbackPopup(L("Für dieses Item fehlt eine gültige Item-ID."))
                return
            end

            local items = GTC.db and GTC.db.items
            local selectedRecord = type(items) == "table"
                and items[tostring(selectedID)] or nil

            -- Modus "Item in Beschreibung einfuegen": nur den Link einsetzen (hier ist
            -- auch ein BoP-Gegenstand erlaubt, er wird ja nur erwaehnt, nicht gehandelt).
            if GTC.catalogInsertTarget == "description" and GTC.descriptionLinkTarget then
                local descriptionLink = selected.itemLink
                if not IsValidCatalogLink(descriptionLink) and type(selectedRecord) == "table" then
                    descriptionLink = selectedRecord.itemLink
                end
                if not IsValidCatalogLink(descriptionLink)
                    and C_Item and type(C_Item.GetItemInfo) == "function" then
                    local _, loadedLink = C_Item.GetItemInfo(selectedID)
                    if IsValidCatalogLink(loadedLink) then
                        descriptionLink = loadedLink
                    end
                end
                if not IsValidCatalogLink(descriptionLink) then
                    RequestCatalogItemData(selectedID)
                    ShowGTCItemFeedbackPopup(
                        L("Der Item-Link wird noch geladen. Bitte kurz warten und erneut versuchen.")
                    )
                    return
                end

                GTC.descriptionLinkTarget:Insert(descriptionLink)
                GTC:SetWindowStatus(L("Link in Beschreibung eingefügt"))
                catalogSearch:ClearFocus()
                itemCatalogFrame:Hide()
                GTC.itemLinkTarget = GTC.descriptionLinkTarget
                GTC.itemLinkCaptureActive = true
                GTC.descriptionLinkTarget:SetFocus()
                return
            end

            local bindType = type(selectedRecord) == "table"
                and selectedRecord.bindType or selected.bindType

            if type(bindType) ~= "number" then
                RequestCatalogItemData(selectedID)

                ShowGTCItemFeedbackPopup(
                    L("Die Item-Daten werden noch geladen. Bitte kurz warten und erneut versuchen.")
                )
                return
            end

            if bindType == 1 then
                ShowGTCItemFeedbackPopup(
                    L("BoP-Items (Bind on Pickup) können nicht als GTC-Inserat gespeichert werden.")
                )
                return
            end

            local link = selected.itemLink
            if not IsValidCatalogLink(link)
                and type(selectedRecord) == "table" then
                link = selectedRecord.itemLink
            end

            if not IsValidCatalogLink(link)
                and C_Item and type(C_Item.GetItemInfo) == "function" then
                local _, loadedLink = C_Item.GetItemInfo(selectedID)
                if IsValidCatalogLink(loadedLink) then
                    link = loadedLink
                end
            end

            if not IsValidCatalogLink(link) then
                RequestCatalogItemData(selectedID)
                ShowGTCItemFeedbackPopup(
                    L("Der Item-Link wird noch geladen. Bitte kurz warten und erneut versuchen.")
                )
                return
            end

            itemBox:SetText(link)
            itemBox:SetCursorPosition(0)
            GTC.itemLinkCaptureActive = true
            catalogSearch:ClearFocus()
            itemCatalogFrame:Hide()
            itemBox:SetFocus()
        end)

        row:SetScript("OnEnter", function(button)
            local selected = button.catalogItem
            if type(selected) ~= "table" then
                GameTooltip:Hide()
                return
            end

            local link = selected.itemLink
            if not IsValidCatalogLink(link) then
                local selectedID = tonumber(selected.itemID)
                if selectedID and C_Item
                    and type(C_Item.GetItemInfo) == "function" then
                    local _, loadedLink = C_Item.GetItemInfo(selectedID)
                    if IsValidCatalogLink(loadedLink) then
                        link = loadedLink
                        selected.itemLink = loadedLink
                    end
                end
            end

            if not IsValidCatalogLink(link) then
                GameTooltip:Hide()
                return
            end

            GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(link)
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        catalogRows[index] = row
        return row
    end

    RefreshItemCatalog = function(keepScroll)
        local savedScroll = keepScroll == true and (tonumber(catalogScroll:GetVerticalScroll()) or 0) or 0
        local entries = {}
        local db = GTC.db
        local query = (catalogSearch:GetText() or ""):lower()
        local qualities = U3.catalogQualities
        local hasQualityFilter = type(qualities) == "table"
            and next(qualities) ~= nil

        if db and type(db.items) == "table" then
            for key, item in pairs(db.items) do
                if type(item) == "table" then
                    local itemID = tonumber(item.itemID) or tonumber(key)

                    if itemID and itemID > 0 then
                        local name = type(item.name) == "string"
                            and item.name ~= "" and item.name
                            or ("Item #" .. tostring(itemID))

                        local idText = tostring(itemID)
                        -- Die Live-Abfrage (mit Server-Anfrage fuer ungeladene Items) nur bei
                        -- aktivem Qualitaetsfilter. Sonst wurden beim Oeffnen fuer jeden Eintrag
                        -- ohne gespeicherte Qualitaet Item-Daten angefordert (bis zu 20.000).
                        local quality
                        if hasQualityFilter then
                            quality = U3.GetItemQuality(itemID)
                        else
                            quality = tonumber(item.quality)
                        end
                        local qualityMatches = not hasQualityFilter
                            or (quality ~= nil and qualities[quality] == true)
                        local lowerName = name:lower()

                        if qualityMatches
                            and (query == ""
                                or lowerName:find(query, 1, true)
                                or idText:find(query, 1, true)) then

                            local link = IsValidCatalogLink(item.itemLink)
                                and item.itemLink or nil

                            table.insert(entries, {
                                itemID = itemID,
                                name = name,
                                sortName = lowerName,
                                itemLink = link,
                                icon = item.icon,
                                bindType = item.bindType,
                                quality = quality,
                            })
                        end
                    end
                end
            end
        end

        -- Kleinschreibung vorab berechnet: vorher entstanden im Vergleich bei jeder
        -- Sortierung zwei neue Strings pro Vergleich (n log n).
        table.sort(entries, function(a, b)
            local an = a.sortName
            local bn = b.sortName

            if an == bn then
                return a.itemID < b.itemID
            end

            return an < bn
        end)

        catalogEntries = entries

        catalogContent:SetWidth(440)
        catalogContent:SetHeight(math.max(1, #catalogEntries * 42))

        catalogEmpty:SetText(
            hasQualityFilter
                and L("Keine Items mit den ausgewählten Qualitäten gefunden.")
                or (query == ""
                    and L("Keine Katalogeinträge verfügbar. Bitte scannen oder Item-Daten laden lassen.")
                    or L("Keine passenden Katalogeinträge gefunden."))
        )
        catalogEmpty:SetShown(#catalogEntries == 0)

        local maxScroll = math.max(0, (#catalogEntries * 42) - (tonumber(catalogScroll:GetHeight()) or 0))
        savedScroll = math.min(savedScroll, maxScroll)
        catalogScroll:SetVerticalScroll(savedScroll)
        if RenderCatalogRows then
            RenderCatalogRows(savedScroll)
        end
    end

    RenderCatalogRows = function(offset)
        local scrollOffset = tonumber(offset)
        if not scrollOffset then
            scrollOffset = tonumber(catalogScroll:GetVerticalScroll()) or 0
        end

        local viewportHeight = tonumber(catalogScroll:GetHeight()) or 0
        if viewportHeight < 1 then viewportHeight = 504 end

        local visibleCount = math.ceil(viewportHeight / 42) + 2
        local firstIndex = math.floor(math.max(0, scrollOffset) / 42) + 1

        for slot = 1, visibleCount do
            local entryIndex = firstIndex + slot - 1
            local item = catalogEntries[entryIndex]
            local row = EnsureCatalogRow(slot)

            if item then
                -- Fehlende Item-Daten fuer sichtbare Zeilen leise nachladen.
                if not item.itemLink and type(GTC.UpdateItemMetadata) == "function" then
                    pcall(GTC.UpdateItemMetadata, GTC, item.itemID, true)
                end
                row.catalogItem = item
                row:ClearAllPoints()
                row:SetPoint(
                    "TOPLEFT",
                    catalogContent,
                    "TOPLEFT",
                    0,
                    -((entryIndex - 1) * 42)
                )

                -- Erst die Farbkennung aus dem echten WoW-Item-Link nutzen.
                -- So funktioniert die Farbe auch dann, wenn die Qualitaets-
                -- Metadaten im Katalog noch nicht vollstaendig geladen sind.
                local hex
                if type(item.itemLink) == "string" then
                    hex = item.itemLink:match("|[cC](%x%x%x%x%x%x%x%x)|[hH]item:")
                end

                -- Fallback: Qualitaetsinformationen aus der Datenbank/API.
                if type(hex) ~= "string" or not hex:match("^%x%x%x%x%x%x%x%x$") then
                    hex = nil
                    local qualityColor = item.quality
                        and ITEM_QUALITY_COLORS
                        and ITEM_QUALITY_COLORS[item.quality] or nil

                    if qualityColor then
                        if type(qualityColor.hex) == "string"
                            and qualityColor.hex:match("^%x%x%x%x%x%x%x%x$") then
                            hex = qualityColor.hex
                        elseif type(qualityColor.r) == "number"
                            and type(qualityColor.g) == "number"
                            and type(qualityColor.b) == "number" then
                            hex = string.format(
                                "ff%02x%02x%02x",
                                math.floor(qualityColor.r * 255 + 0.5),
                                math.floor(qualityColor.g * 255 + 0.5),
                                math.floor(qualityColor.b * 255 + 0.5)
                            )
                        end
                    end
                end

                local labelName = item.name
                if type(hex) == "string" and hex:match("^%x%x%x%x%x%x%x%x$") then
                    labelName = "|c" .. hex .. labelName .. "|r"
                end

                row.label:SetText(
                    labelName
                    .. "  |cff888888(ID "
                    .. tostring(item.itemID or "?")
                    .. ")|r"
                )

                if type(item.icon) == "number"
                    or type(item.icon) == "string" then
                    row.iconTexture:SetTexture(item.icon)
                    row.iconTexture:Show()
                else
                    row.iconTexture:SetTexture(nil)
                    row.iconTexture:Hide()
                end

                row:Show()
            else
                row.catalogItem = nil
                row:Hide()
            end
        end

        for slot = visibleCount + 1, #catalogRows do
            catalogRows[slot]:Hide()
        end
    end

    -- Hintergrund-Aufloeser: Namen/Bindung fuer Eintraege ohne Daten (z. B. aus dem
    -- Gilden-Katalog) langsam nachladen, damit auch die Namenssuche greift.
    local resolverQueue, resolverRunning = {}, false
    local function ResolverStep()
        if not itemCatalogFrame:IsShown() then
            resolverRunning = false
            return
        end
        local processed = 0
        while processed < 12 and #resolverQueue > 0 do
            local key = table.remove(resolverQueue)
            pcall(GTC.UpdateItemMetadata, GTC, tonumber(key), true)
            processed = processed + 1
        end
        if #resolverQueue > 0 then
            C_Timer.After(0.6, ResolverStep)
        else
            resolverRunning = false
            RefreshItemCatalog(true)
        end
    end
    local function StartCatalogResolver()
        if resolverRunning then return end
        local db = GTC.db
        resolverQueue = {}
        for key, item in pairs(db and db.items or {}) do
            if type(item) == "table" and (type(item.name) ~= "string" or item.name == "") then
                resolverQueue[#resolverQueue + 1] = key
            end
        end
        if #resolverQueue > 0 then
            resolverRunning = true
            C_Timer.After(0.2, ResolverStep)
        end
    end

    local function UpdateCatalogStatus(text)
        local count = 0
        for _ in pairs(GTC.db and GTC.db.items or {}) do count = count + 1 end
        catalogStatus:SetText(text or (L("Katalog: ") .. count .. L(" Items")))
    end

    catalogLoad:SetScript("OnClick", function()
        local ok, message = GTC:RequestGuildCatalog()
        catalogStatus:SetText(message or "")
        if not ok then
            ShowGTCItemFeedbackPopup(message)
        end
    end)

    function GTC:OnCatalogReceived(added, total)
        UpdateCatalogStatus(L("Erhalten: ") .. tostring(total) .. L(" IDs, ") .. tostring(added) .. L(" neu"))
        if itemCatalogFrame:IsShown() then
            RefreshItemCatalog(true)
            StartCatalogResolver()
        end
    end

    itemCatalogFrame:HookScript("OnShow", function()
        UpdateCatalogStatus()
        StartCatalogResolver()
    end)

    catalogScroll:SetScript("OnVerticalScroll", function(_, offset)
        if RenderCatalogRows then
            RenderCatalogRows(offset)
        end
    end)

    do
        local catalogQualityButton = Button(itemCatalogFrame, L("Qualität"), 105, 26)
        catalogQualityButton:SetPoint("LEFT", catalogSearch, "RIGHT", 8, 0)
        local catalogQualityControls = U3.AttachQualityMenu(
            itemCatalogFrame,
            catalogQualityButton,
            U3.catalogQualities,
            function() RefreshItemCatalog() end
        )
        U3.catalogQualityControls = catalogQualityControls
    end

    -- Ereignisgesteuerte Aktualisierung (nachgeladene Item-Daten): Scrollposition behalten.
    GTC.RefreshItemCatalog = function()
        if itemCatalogFrame:IsShown() then RefreshItemCatalog(true) end
    end
    GTC.IsItemCatalogShown = function()
        return itemCatalogFrame:IsShown()
    end

    catalogSearch:SetScript("OnTextChanged", function()
        catalogSearchGeneration = catalogSearchGeneration + 1
        local request = catalogSearchGeneration

        if C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0.15, function()
                if request == catalogSearchGeneration
                    and itemCatalogFrame:IsShown() then
                    RefreshItemCatalog()
                end
            end)
        else
            RefreshItemCatalog()
        end
    end)

    catalogButton:SetScript("OnClick", function()
        GTC.catalogInsertTarget = "item"
        catalogTitle:SetText(L("Item aus Katalog auswählen"))
        catalogSearch:SetText("")
        RefreshItemCatalog()
        itemCatalogFrame:Show()
        catalogSearch:SetFocus()
    end)

    local catalogBindingEventFrame = CreateFrame("Frame")
    catalogBindingEventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    catalogBindingEventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")
    catalogBindingEventFrame:SetScript("OnEvent", function(_, event, loadedItemID, succeeded)
        -- Nur bei offenem Katalog und erfolgreich geladenen Daten.
        if succeeded == false or not itemCatalogFrame:IsShown() then
            return
        end

        local itemID = tonumber(loadedItemID)
        if not itemID then
            return
        end

        local db = GTC.db
        local items = db and db.items
        local entry = type(items) == "table" and items[tostring(itemID)] or nil
        if type(entry) ~= "table" then
            return
        end

        -- Gebuendelt und nach den anderen Item-Event-Handlern (bindType ist dann
        -- aktualisiert). Scrollposition bleibt erhalten: vorher sprang die Liste bei
        -- jedem nachgeladenen Item wieder nach oben.
        ScheduleRefresh("catalog", 0.3, function()
            if itemCatalogFrame:IsShown() then
                RefreshItemCatalog(true)
            end
        end)
    end)

    if not GTC.itemLinkHooksInstalled and type(hooksecurefunc) == "function" then
        -- Links ueber die alten und aktuellen WoW-Einstiegspunkte abfangen.
        local function CaptureGTCLink(link)
            local target = GTC.itemLinkTarget

            if not GTC.itemLinkCaptureActive or not target then
                return
            end
            if type(link) ~= "string" then
                return
            end

            local linkType = link:match("|[Hh]([%w_]+):")
                or link:match("^([%w_]+):")
            if not linkType then
                return
            end

            -- Doppelte Erfassung verhindern, falls WoW beide Hooks aufruft.
            local now = type(GetTime) == "function" and GetTime() or nil
            if now and GTC._gtcLastCapturedLink == link
                and now - (GTC._gtcLastCapturedAt or -1) < 0.15 then
                return
            end
            if now then
                GTC._gtcLastCapturedLink = link
                GTC._gtcLastCapturedAt = now
            end

            local isDescriptionTarget =
                GTC.descriptionLinkTarget ~= nil
                and target == GTC.descriptionLinkTarget

            -- Das Hauptfeld nimmt Gegenstands- und Berufs-Links (trade:) an.
            local lowerType = string.lower(linkType)
            if not isDescriptionTarget and lowerType ~= "item" and lowerType ~= "trade" then
                return
            end

            if isDescriptionTarget then
                target:Insert(link)
                GTC:SetWindowStatus(L("Link in Beschreibung eingefügt"))
            elseif lowerType == "trade" then
                local pid = GTC.Prof and GTC.Prof:Parse(link)
                if not pid then
                    GTC:SetWindowStatus(L("Berufs-Link nicht erkannt"))
                    return
                end
                GTC.Prof:RequestTokenItem(pid)
                target:SetText(link)
                target:SetCursorPosition(0)
                GTC:SetWindowStatus(L("Berufs-Link übernommen: ") .. GTC.Prof:Name(pid))
            else
                target:SetText(link)
                target:SetCursorPosition(0)
                GTC:SetWindowStatus(L("Item-Link übernommen"))
            end
        end

        if type(ChatFrameUtil) == "table"
            and type(ChatFrameUtil.InsertLink) == "function"
            and not GTC.chatFrameUtilLinkHookInstalled then
            hooksecurefunc(ChatFrameUtil, "InsertLink", CaptureGTCLink)
            GTC.chatFrameUtilLinkHookInstalled = true
        end

        if type(ChatEdit_InsertLink) == "function"
            and not GTC.chatEditLinkHookInstalled then
            hooksecurefunc("ChatEdit_InsertLink", CaptureGTCLink)
            GTC.chatEditLinkHookInstalled = true
        end

        GTC.chatItemLinkHookInstalled =
            GTC.chatFrameUtilLinkHookInstalled or GTC.chatEditLinkHookInstalled        -- Shift-Klick auf einen Gegenstand in den Taschen abfangen.
        local mixin = ContainerFrameItemButtonMixin

        if mixin and type(mixin.OnModifiedClick) == "function" then
            hooksecurefunc(mixin, "OnModifiedClick", function(button, mouseButton)
                if not GTC.itemLinkCaptureActive or not GTC.itemLinkTarget then
                    return
                end

                if mouseButton ~= "LeftButton" or not IsModifiedClick("CHATLINK") then
                    return
                end

                local parent = button and button.GetParent and button:GetParent()
                local bagID = parent and parent.GetID and parent:GetID()
                local slotID = button and button.GetID and button:GetID()

                if bagID == nil or slotID == nil then
                    return
                end

                local link = C_Container and C_Container.GetContainerItemLink
                    and C_Container.GetContainerItemLink(bagID, slotID)

                if link then
                    -- Doppeltes Einfuegen verhindern, wenn bereits
                    -- ein anderer Hook denselben Link verarbeitet hat.
                    local now = type(GetTime) == "function" and GetTime() or nil

                    if now and GTC._gtcLastCapturedLink == link
                        and now - (GTC._gtcLastCapturedAt or -1) < 0.15 then
                        return
                    end

                    if now then
                        GTC._gtcLastCapturedLink = link
                        GTC._gtcLastCapturedAt = now
                    end

                    if GTC.itemLinkTarget == GTC.descriptionLinkTarget then
                        GTC.itemLinkTarget:Insert(link)
                        GTC:SetWindowStatus(L("Item-Link in Beschreibung eingefügt"))
                    else
                        GTC.itemLinkTarget:SetText(link)
                        GTC.itemLinkTarget:SetCursorPosition(0)
                    end
                end
            end)
        end

        GTC.itemLinkHooksInstalled = true
    end

    FormLabel(L("Menge:"), -120)
    local quantityBox = FormInput(100, -116, "1")

    -- v1.1.7: Beruf statt Gegenstand einsetzen.
    local professionButton = Button(formPanel, L("Beruf"), 70, 24)
    professionButton:SetPoint("LEFT", catalogButton, "RIGHT", 8, 0)
    AddTooltip(professionButton, L("Beruf einfügen"), L("Setzt einen Beruf statt eines Gegenstands ein, z. B. [Schmiedekunst]. Andere sehen per Klick alle Rezepte, die du in diesem Beruf kennst. Alternativ: Shift-Klick auf den Berufs-Link im Berufsfenster."))

    local professionMenu = CreateFrame("Frame", "GTCProfessionMenu", UIParent, "UIDropDownMenuTemplate")
    professionMenu:Hide()

    local function ApplyProfession(pid)
        if not Prof then return end
        Prof:RequestTokenItem(pid)
        itemBox:SetText(Prof:CurrentNativeLink(pid) or Prof:BuildLink(pid))
        itemBox:SetCursorPosition(0)
        quantityBox:SetText("1")
        GTC:SetWindowStatus(L("Beruf übernommen: ") .. Prof:Name(pid))
    end

    UIDropDownMenu_Initialize(professionMenu, function(_, level)
        if not Prof then return end
        local own = Prof:OwnProfessions()
        local list = {}
        for pid in pairs(Prof.INFO) do list[#list + 1] = pid end
        table.sort(list, function(a, b)
            local oa, ob = own[a] and 1 or 0, own[b] and 1 or 0
            if oa ~= ob then return oa > ob end
            return Prof:Name(a) < Prof:Name(b)
        end)

        local header = UIDropDownMenu_CreateInfo()
        header.text = L("Beruf wählen")
        header.isTitle = true
        header.notCheckable = true
        UIDropDownMenu_AddButton(header, level)

        for _, pid in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            local mine = own[pid]
            local extra = ""
            if mine and (tonumber(mine.count) or 0) > 0 then
                extra = "  |cff7fd8ff" .. (L("%d Rezepte")):format(mine.count) .. "|r"
            elseif mine and (tonumber(mine.s) or 0) > 0 then
                extra = "  |cff7fd8ff(" .. tostring(mine.s) .. ")|r"
            end
            info.text = Prof:Name(pid) .. extra
            info.icon = Prof:Icon(pid)
            info.notCheckable = true
            if not mine then info.colorCode = "|cff9d9d9d" end
            info.func = function() ApplyProfession(pid) end
            UIDropDownMenu_AddButton(info, level)
        end
    end, "MENU")

    professionButton:SetScript("OnClick", function(button)
        ToggleDropDownMenu(1, nil, professionMenu, button, 0, 0)
    end)

    FormLabel(L("Handelsart:"), -168)
    local tradeTypeDropdown = CreateFrame(
        "Frame", "GTCTradeTypeDropdown", formPanel, "UIDropDownMenuTemplate"
    )
    tradeTypeDropdown:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 158, -158)
    UIDropDownMenu_SetWidth(tradeTypeDropdown, 190)

    local tradeTypes = {
        { text = L("Tausch"), value = "Tausch" },
        { text = L("Verkauf"), value = "Verkauf" },
        { text = L("Kostenlos"), value = "Kostenlos" },
        { text = L("Kaufe"), value = "Kaufe" },
    }

    UIDropDownMenu_Initialize(tradeTypeDropdown, function(self, level)
        for _, option in ipairs(tradeTypes) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = option.text
            info.value = option.value
            info.func = function()
                UIDropDownMenu_SetSelectedValue(tradeTypeDropdown, option.value)
                UIDropDownMenu_SetText(tradeTypeDropdown, option.text)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    UIDropDownMenu_SetSelectedValue(tradeTypeDropdown, "Tausch")
    UIDropDownMenu_SetText(tradeTypeDropdown, L("Tausch"))

    FormLabel(L("Beschreibung:"), -216)
    local descriptionBox = FormInput(420, -212, "")
    GTC.descriptionLinkTarget = descriptionBox
    descriptionBox:SetMaxLetters(1000)
    descriptionBox:SetScript("OnEditFocusGained", function()
        GTC.itemLinkTarget = descriptionBox
    end)

    local descriptionLinkButton = Button(formPanel, L("Item einfügen"), 120, 24)
    descriptionLinkButton:SetPoint("LEFT", descriptionBox, "RIGHT", 8, 0)
    descriptionLinkButton:SetScript("OnClick", function()
        GTC.catalogInsertTarget = "description"
        catalogTitle:SetText(L("Item in Beschreibung einfügen"))
        catalogSearch:SetText("")
        RefreshItemCatalog()
        itemCatalogFrame:Show()
        catalogSearch:SetFocus()
    end)

    local descriptionHint = formPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    descriptionHint:SetPoint("TOPLEFT", descriptionBox, "BOTTOMLEFT", 4, -2)
    descriptionHint:SetText(L("Gegenstände per Shift-Klick oder über den Button einfügen."))
    descriptionHint:SetTextColor(unpack(C.muted))

    local formKind = "offer"
    local kindLabel = FormLabel(L("Eintragstyp:"), -264)

    local offerKindButton = Button(formPanel, L("Angebot"), 120, 28)
    offerKindButton:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 180, -256)

    local wantedKindButton = Button(formPanel, L("Gesuch"), 120, 28)
    wantedKindButton:SetPoint("LEFT", offerKindButton, "RIGHT", 8, 0)

    FormLabel(L("Laufzeit (Stunden):"), -310)
    local durationSlider = CreateFrame("Slider", nil, formPanel, "OptionsSliderTemplate")
    durationSlider:SetSize(260, 16)
    durationSlider:SetPoint("TOPLEFT", formPanel, "TOPLEFT", 180, -310)
    durationSlider:SetMinMaxValues(1, 72)
    durationSlider:SetValueStep(1)
    if durationSlider.SetObeyStepOnDrag then
        durationSlider:SetObeyStepOnDrag(true)
    end

    local durationValueText = formPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    durationValueText:SetPoint("LEFT", durationSlider, "RIGHT", 8, 0)
    durationValueText:SetText(L("24 Std."))

    durationSlider:SetScript("OnValueChanged", function(slider, value)
        local rounded = math.max(1, math.min(72, math.floor((tonumber(value) or 24) + 0.5)))
        if math.abs((tonumber(value) or rounded) - rounded) > 0.01 then
            slider:SetValue(rounded)
            return
        end
        durationValueText:SetText(tostring(rounded) .. L(" Std."))
    end)
    durationSlider:SetValue(24)

    local function SetFormKind(kind)
        formKind = kind
        kindLabel:SetText(L("Eintragstyp: ") .. (kind == "offer" and L("Angebot") or L("Gesuch")))

        local defaultTrade = (kind == "wanted") and "Kaufe" or "Tausch"
        UIDropDownMenu_SetSelectedValue(tradeTypeDropdown, defaultTrade)
        UIDropDownMenu_SetText(tradeTypeDropdown, L(defaultTrade))
    end

    offerKindButton:SetScript("OnClick", function()
        SetFormKind("offer")
    end)

    wantedKindButton:SetScript("OnClick", function()
        SetFormKind("wanted")
    end)

    local editingEntry = nil

    local function BeginEditCurrentEntry()
        local entry = self.currentDetailEntry
        if not entry then
            GTC:Print(L("Kein Eintrag ausgewählt."))
            return
        end

        local playerName = GTC:GetFullPlayerName()
        if not playerName or not GTC:SameCharacter(entry.character, playerName) or entry.isTest ~= false then
            GTC:Print(L("Nur eigene echte Einträge können bearbeitet werden."))
            return
        end

        editingEntry = entry
        formTitle:SetText(L("Eintrag bearbeiten"))
        SetFormKind(entry.kind or "offer")
        local editProf = EntryProf(entry)
        if editProf then
            itemBox:SetText(Prof:SanitizeNativeLink(entry.professionLink) or Prof:BuildLink(editProf))
            Prof:RequestTokenItem(editProf)
        else
            itemBox:SetText(entry.itemLink or tostring(entry.itemID or ""))
        end
        quantityBox:SetText(tostring(entry.quantity or 1))
        durationSlider:SetValue(math.max(1, math.min(72, math.floor((tonumber(entry.durationHours) or 24) + 0.5))))

        local tradeText = entry.tradeType or L("Tausch")
        UIDropDownMenu_SetSelectedValue(tradeTypeDropdown, tradeText)
        UIDropDownMenu_SetText(tradeTypeDropdown, L(tradeText))
        descriptionBox:SetText(entry.description or "")

        GTC.itemLinkCaptureActive = true
        GTC.itemLinkTarget = itemBox
        detail:Hide()
        listPanel:Hide()
        formPanel:Show()
    end

    local function ConfirmDeleteCurrentEntry()
        local entry = self.currentDetailEntry
        if not entry then
            GTC:Print(L("Kein Eintrag ausgewählt."))
            return
        end

        local playerName = GTC:GetFullPlayerName()
        if not playerName or not GTC:SameCharacter(entry.character, playerName) or entry.isTest ~= false then
            GTC:Print(L("Nur eigene echte Einträge können gelöscht werden."))
            return
        end

        StaticPopupDialogs["GTC_CONFIRM_DELETE_LISTING"] = {
            text = L("Diesen eigenen Eintrag wirklich löschen?"),
            button1 = L("Löschen"),
            button2 = L("Abbrechen"),
            OnAccept = function()
                local ok, result = GTC:DeleteLocalListing(entry.id, GTC:GetFullPlayerName())
                if not ok then
                    GTC:Print(result or L("Der Eintrag konnte nicht gelöscht werden."))
                    return
                end

                GTC.itemLinkCaptureActive = false
                self.currentDetailEntry = nil
                editingEntry = nil
                detail:Hide()
                listPanel:Show()
                self:RefreshListingView()
                GTC:SetWindowStatus(L("Eintrag gelöscht"))
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }

        StaticPopup_Show("GTC_CONFIRM_DELETE_LISTING")
    end

    editEntryButton:SetScript("OnClick", BeginEditCurrentEntry)
    deleteEntryButton:SetScript("OnClick", ConfirmDeleteCurrentEntry)

    local saveEntry = Button(formPanel, L("Speichern"), 130, 30)
    saveEntry:SetPoint("BOTTOMLEFT", formPanel, "BOTTOMLEFT", 22, 18)

    local cancelEntry = Button(formPanel, L("Abbrechen"), 130, 30)
    cancelEntry:SetPoint("LEFT", saveEntry, "RIGHT", 8, 0)

    saveEntry:SetScript("OnClick", function()
        local linkText = itemBox:GetText()
        local amountText = quantityBox:GetText()
        local tradeText = UIDropDownMenu_GetSelectedValue(tradeTypeDropdown) or L("Tausch")
        local descriptionText = descriptionBox:GetText()

        local wasEditing = editingEntry ~= nil
        local ok, result

        if editingEntry then
            ok, result = GTC:UpdateLocalListing(
                editingEntry.id,
                linkText,
                amountText,
                tradeText,
                descriptionText,
                formKind,
                GTC:GetFullPlayerName(),
                math.floor(durationSlider:GetValue() + 0.5)
            )
        else
            ok, result = GTC:CreateLocalListing(
                linkText,
                amountText,
                tradeText,
                descriptionText,
                formKind,
                math.floor(durationSlider:GetValue() + 0.5)
            )
        end

        if not ok then
            ShowGTCItemFeedbackPopup(result or L("Der Eintrag konnte nicht gespeichert werden."))
            return
        end

        GTC.itemLinkCaptureActive = false
        editingEntry = nil
        formTitle:SetText(L("Neuen Eintrag erstellen"))
        self.activeTab = formKind
        self.currentPage = 1
        formPanel:Hide()
        detail:Hide()
        listPanel:Show()
        self:RefreshListingView()
        if wasEditing then
            GTC:SetWindowStatus(L("Eintrag aktualisiert (ID ") .. tostring(result) .. ").")
        else
            GTC:SetWindowStatus(L("Eintrag lokal gespeichert (Item-ID ") .. tostring(result) .. ").")
        end
    end)

    cancelEntry:SetScript("OnClick", function()
        GTC.itemLinkCaptureActive = false
        formPanel:Hide()
        formTitle:SetText(L("Neuen Eintrag erstellen"))

        if editingEntry then
            editingEntry = nil
            detail:Show()
        else
            listPanel:Show()
        end
    end)

    createEntry:SetScript("OnClick", function()
        editingEntry = nil
        formTitle:SetText(L("Neuen Eintrag erstellen"))
        SetFormKind(self.activeTab or "offer")
        GTC.itemLinkCaptureActive = true
        GTC.itemLinkTarget = itemBox
        itemBox:SetText("")
        quantityBox:SetText("1")
        local defaultTrade = (formKind == "wanted") and "Kaufe" or "Tausch"
        UIDropDownMenu_SetSelectedValue(tradeTypeDropdown, defaultTrade)
        UIDropDownMenu_SetText(tradeTypeDropdown, L(defaultTrade))
        durationSlider:SetValue(24)
        descriptionBox:SetText("")
        detail:Hide()
        listPanel:Hide()
        formPanel:Show()
    end)

    local function OpenListing(entry)
        local displayName = tostring(entry.item or L("Unbekannter Gegenstand"))
        local titleLink = entry.itemLink
        local entryProf = EntryProf(entry)

        -- Auch einfache item:-Referenzen in gueltige Hyperlinks umwandeln.
        if type(titleLink) == "string" and titleLink:match("^item:%d+") then
            titleLink = "|H" .. titleLink .. "|h[" .. displayName .. "]|h"
        end

        if entryProf then
            detailTitle:SetText(Prof:BuildLink(entryProf))
        elseif type(titleLink) == "string" and titleLink:match("|[Hh][%w_]+:") then
            detailTitle:SetText(titleLink)
        else
            detailTitle:SetText(displayName)
        end
        local statusPrefix = entry.completed == true and "|cff2ecc71ABGESCHLOSSEN|r  |  " or ""
        if entry.kind == "offer" then
            detailType:SetText(statusPrefix .. L("ANGEBOT  |  ") .. L(tostring(entry.tradeType or L("Nicht angegeben"))))
        else
            detailType:SetText(statusPrefix .. L("GESUCH  |  ") .. L(tostring(entry.tradeType or L("Nicht angegeben"))))
        end

        detailQty:SetText(L("Menge: ") .. tostring(entry.quantity or 1))
        if entryProf then
            if entry.kind == "wanted" then
                detailQty:SetText(L("Gesucht: ein Handwerker für diesen Beruf"))
                profRecipesButton:SetText(L("Handwerker in der Gilde"))
            else
                local info = Prof:RecipeInfo(entry)
                if info and info.count then
                    local skill = (info.s and info.s > 0) and ("  |cff9fb3c8(" .. L("Fertigkeit ") .. info.s
                        .. ((info.m and info.m > 0) and ("/" .. info.m) or "") .. ")|r") or ""
                    detailQty:SetText((L("Bekannte Rezepte: %d")):format(info.count) .. skill)
                else
                    detailQty:SetText(L("Bekannte Rezepte: noch nicht synchronisiert"))
                end
                profRecipesButton:SetText(L("Rezepte ansehen"))
            end
            profRecipesButton:Show()
            profNativeButton:SetShown(Prof:SanitizeNativeLink(entry.professionLink) ~= nil)
        else
            profRecipesButton:Hide()
            profNativeButton:Hide()
        end
        self.currentDetailEntry = entry

        local playerName = GTC:GetFullPlayerName()
        local canManage = entry.isTest == false
            and playerName ~= nil
            and GTC:SameCharacter(entry.character, playerName)
        RefreshWatchButton(entry)
        editEntryButton:SetShown(canManage)
        deleteEntryButton:SetShown(canManage)
        completeEntryButton:SetShown(canManage and entry.completed ~= true)

        characterNameText:SetText(tostring(entry.character or L("Unbekannt")))
        local characterTextWidth = math.ceil(characterNameText:GetStringWidth())
        characterNameText:SetWordWrap(false)
        characterNameText:SetWidth(math.min(396, characterTextWidth))
        detailCharacter:SetWidth(math.min(420, math.max(120, characterTextWidth + 24)))

        detailDescription:SetText(tostring(entry.description or L("Keine Beschreibung hinterlegt.")))

        listPanel:Hide()
        detail:Show()
    end
    GTC._gtcOpenListing = OpenListing

    completeEntryButton:SetScript("OnClick", function()
        local entry = self.currentDetailEntry
        if not entry then
            GTC:Print(L("Kein Eintrag ausgewählt."))
            return
        end

        local ok, result = GTC:CompleteLocalListing(entry.id, GTC:GetFullPlayerName())
        if not ok then
            GTC:Print(result or L("Eintrag konnte nicht abgeschlossen werden."))
            return
        end

        OpenListing(entry)
        self:RefreshListingView()
        GTC:SetWindowStatus(L("Eintrag als abgeschlossen markiert"))
    end)

    -- GTC_LISTING_ITEM_TOOLTIP (v1.1.6)
    -- Beim Hovern ueber eine Karte in der Angebots-/Gesuchsliste den echten Item-Tooltip
    -- des inserierten Gegenstands zeigen. Bevorzugt der gespeicherte Item-Link (enthaelt
    -- z. B. Zufallsboni wie "...des Baeren"), sonst die Item-ID. Rein lokal, das
    -- Sync-Format bleibt unveraendert.
    local LISTING_TOOLTIP_MAX_RETRIES = 4

    -- Liefert den rohen Hyperlink "item:..." fuer GameTooltip:SetHyperlink.
    -- Gesyncte Links stammen von anderen Spielern, daher nur Ziffern/Doppelpunkte/Minus zulassen.
    local function ListingTooltipHyperlink(entry)
        if type(entry) ~= "table" then
            return nil
        end
        local stored = entry.itemLink
        if type(stored) == "string" then
            local raw = stored:match("|H(item:[%-%d:]+)|h") or stored:match("^(item:[%-%d:]+)$")
            if raw and tonumber(raw:match("^item:(%d+)")) then
                return raw
            end
        end
        local itemID = tonumber(entry.itemID)
        if itemID and itemID > 0 and itemID == math.floor(itemID) then
            return "item:" .. tostring(itemID)
        end
        return nil
    end

    -- Vollstaendiger, klickbarer Item-Link fuer Shift-/Strg-Klick (Chat, Anprobe).
    local function ListingChatLink(entry)
        if type(entry) ~= "table" then
            return nil
        end
        if EntryProf(entry) then
            -- Nur der native Berufs-Link ist im Chat versendbar.
            return (Prof:SanitizeNativeLink(entry.professionLink))
        end
        local stored = entry.itemLink
        if type(stored) == "string" and stored:match("^|c%x+|Hitem:[%-%d:]+|h%[[^|%]]+%]|h|r$") then
            return stored
        end
        local itemID = tonumber(entry.itemID)
        if itemID and C_Item and type(C_Item.GetItemInfo) == "function" then
            local _, loadedLink = C_Item.GetItemInfo(itemID)
            if type(loadedLink) == "string" then
                return loadedLink
            end
        end
        return nil
    end

    local function IsItemCached(itemID)
        if not itemID then
            return true
        end
        if C_Item and type(C_Item.IsItemDataCachedByID) == "function" then
            return C_Item.IsItemDataCachedByID(itemID) and true or false
        end
        if C_Item and type(C_Item.GetItemInfo) == "function" then
            return C_Item.GetItemInfo(itemID) ~= nil
        end
        return true
    end

    local function ShowListingItemTooltip(card)
        local entry = card and card.gtcEntry
        if type(entry) ~= "table" then
            GameTooltip:Hide()
            return
        end

        GameTooltip:SetOwner(card, "ANCHOR_RIGHT")

        if EntryProf(entry) then
            Prof:FillTooltip(GameTooltip, entry)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(entry.kind == "wanted" and L("Klick: Gesuch öffnen")
                or L("Klick: Inserat öffnen und Rezepte ansehen"), C.cyan[1], C.cyan[2], C.cyan[3], true)
            if Prof:SanitizeNativeLink(entry.professionLink) then
                GameTooltip:AddLine(L("Shift-Klick: Berufs-Link in den Chat"), C.cyan[1], C.cyan[2], C.cyan[3], true)
            end
            GameTooltip:Show()
            return
        end

        local hyperlink = ListingTooltipHyperlink(entry)
        local shown = false
        if hyperlink then
            shown = pcall(GameTooltip.SetHyperlink, GameTooltip, hyperlink)
            shown = shown and GameTooltip:NumLines() > 0
        end

        if not shown then
            -- Kein gueltiges Item (z. B. Altdaten): bisheriger Hinweis-Tooltip.
            GameTooltip:ClearLines()
            GameTooltip:AddLine(L("Eintrag öffnen"), 1, 1, 1)
            GameTooltip:AddLine(L("Zeigt Details, Beschreibung und Kontakt zum Ersteller."), 0.75, 0.84, 0.97, true)
            GameTooltip:Show()
            return
        end

        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L("Klick: Eintrag öffnen  |  Shift-Klick: Link in den Chat"), C.cyan[1], C.cyan[2], C.cyan[3], true)
        GameTooltip:Show()

        -- Item noch nicht im Client-Cache: laden und den Tooltip kurz danach neu aufbauen,
        -- solange die Maus noch auf derselben Karte liegt.
        local itemID = tonumber(hyperlink:match("^item:(%d+)"))
        if not IsItemCached(itemID) then
            if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
                pcall(C_Item.RequestLoadItemDataByID, itemID)
            end
            local retries = (card.gtcTooltipRetries or 0) + 1
            card.gtcTooltipRetries = retries
            if retries <= LISTING_TOOLTIP_MAX_RETRIES and C_Timer and type(C_Timer.After) == "function" then
                local expected = entry
                C_Timer.After(0.25, function()
                    if card.gtcEntry == expected and card:IsShown() and card:IsMouseOver()
                        and GameTooltip:IsOwned(card) then
                        ShowListingItemTooltip(card)
                    end
                end)
            end
        else
            card.gtcTooltipRetries = 0
        end
    end

    for i = 1, 5 do
        local card = CreateFrame("Button", nil, listPanel, "BackdropTemplate")
        card:SetHeight(72)
        card:SetPoint("TOPLEFT", listPanel, "TOPLEFT", 12, -78 - ((i - 1) * 80))
        card:SetPoint("RIGHT", listPanel, "RIGHT", -12, 0)
        Backdrop(card, C.card, C.border)
        -- Tooltip kommt jetzt aus ShowListingItemTooltip (OnEnter unten). Das fruehere
        -- AddTooltip wurde ohnehin vom SetScript("OnEnter") ueberschrieben.

        local iconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
        iconFrame:SetSize(48, 48)
        iconFrame:SetPoint("LEFT", card, "LEFT", 12, 0)
        Backdrop(iconFrame, C.iconPanel, C.gold)

        local iconTexture = iconFrame:CreateTexture(nil, "ARTWORK")
        iconTexture:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 3, -3)
        iconTexture:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -3, 3)
        iconTexture:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        iconTexture:Hide()

        local iconText = iconFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        iconText:SetPoint("CENTER")
        iconText:SetText("G")
        iconText:SetTextColor(unpack(C.cyan))
        iconText:Show()

        local itemName = Text(card, "GameFontNormal", "TOPLEFT", card, "TOPLEFT", 72, -12)

        local meta = Text(card, "GameFontHighlightSmall", "TOPLEFT", card, "TOPLEFT", 72, -32)
        local desc = Text(card, "GameFontHighlightSmall", "TOPLEFT", card, "TOPLEFT", 72, -49)
        desc:SetTextColor(unpack(C.muted))

        local arrow = Text(card, "GameFontNormalLarge", "RIGHT", card, "RIGHT", -15, 0)
        arrow:SetText(">")
        arrow:SetTextColor(unpack(C.cyan))

        card:SetScript("OnEnter", function(self)
            self:SetBackdropColor(unpack(C.cardHover))
            self.gtcTooltipRetries = 0
            ShowListingItemTooltip(self)
        end)
        card:SetScript("OnLeave", function(self)
            self:SetBackdropColor(unpack(C.card))
            self.gtcTooltipRetries = 0
            if GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
        end)

        card:SetScript("OnHyperlinkEnter", function(self, link)
            if type(link) == "string" and link:match("^item:") then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(link)
                GameTooltip:Show()
            end
        end)

        card:SetScript("OnHyperlinkLeave", function()
            GameTooltip:Hide()
        end)

        rows[i] = {
            frame = card,
            name = itemName,
            meta = meta,
            description = desc,
            icon = iconText,
            iconTexture = iconTexture,
        }
    end

    self.activeTab = "offer"
    self.currentPage = 1

    local sampleItemIDs = {
        ["Wollstoff"] = 2592,
        ["Kupferbarren"] = 2840,
        ["Leinenstoff"] = 2589,
        ["Kupfererz"] = 2770,
        ["Grober Stein"] = 2836,
        ["Leichtes Leder"] = 2318,
        ["Friedensblume"] = 2447,
    }

    local function ResolveItemIcon(entry)
        local itemID = tonumber(entry.itemID) or sampleItemIDs[entry.item]
        if not itemID then
            return nil
        end

        local texture
        if C_Item and type(C_Item.GetItemIconByID) == "function" then
            texture = C_Item.GetItemIconByID(itemID)
        end

        if not texture and C_Item and type(C_Item.GetItemInfo) == "function" then
            local _, _, _, _, _, _, _, _, _, iconFileID = C_Item.GetItemInfo(itemID)
            texture = iconFileID
        end

        return texture
    end

    local function ResolveItemLink(entry)
        local itemID = tonumber(entry.itemID) or sampleItemIDs[entry.item]
        if not itemID then
            return nil
        end

        if C_Item and type(C_Item.GetItemInfo) == "function" then
            local _, itemLink = C_Item.GetItemInfo(itemID)
            if itemLink then
                return itemLink
            end
        end

        if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
            C_Item.RequestLoadItemDataByID(itemID)
        end

        return nil
    end

    local function FormatRemainingTime(entry)
        if entry.completed == true then
            return "|cff2ecc71Abgeschlossen|r"
        end

        local expiresAt = tonumber(entry.expiresAt)
        if not expiresAt then
            return L("Restzeit unbekannt")
        end

        local remaining = math.floor(expiresAt - GTC:Now())
        if remaining <= 0 then
            return "|cffff6666Abgelaufen|r"
        end

        local totalMinutes = math.ceil(remaining / 60)
        local hours = math.floor(totalMinutes / 60)
        local minutes = totalMinutes % 60

        if hours >= 24 then
            return string.format(L("noch %dT %dh"), math.floor(hours / 24), hours % 24)
        elseif hours >= 1 then
            return string.format(L("noch %dh %02dm"), hours, minutes)
        else
            return string.format(L("noch %d min"), math.max(1, totalMinutes))
        end
    end

    local previous, nextPage, pageText
    local listingPageCount = 1

    -- Zurueck/Weiter nur zeigen, wenn die Liste sichtbar ist und es in diese Richtung weitergeht.
    function self:UpdatePageButtons()
        local listVisible = listPanel:IsShown()
        local page = self.currentPage or 1
        if previous then previous:SetShown(listVisible and page > 1) end
        if nextPage then nextPage:SetShown(listVisible and page < listingPageCount) end
        if pageText then pageText:SetShown(listVisible) end
    end

    function self:RefreshListingView()
        EnsureData()

        -- Geschlossenes Fenster nicht neu aufbauen (Sync, Ablauf und Item-Ereignisse rufen
        -- das oft auf). Beim Oeffnen wird ohnehin neu aufgebaut (OnShow unten).
        if not root:IsShown() then
            return
        end

        local filtered = {}
        local seen = {}
        local filters = U3.listing
        local searchQuery = tostring(filters.search or ""):lower()
        local playerName = GTC:GetFullPlayerName()
        local hasQualityFilter = next(filters.qualities) ~= nil
        local database = GTC.db

        for _, entry in ipairs((database and database.listings) or {}) do
            local matches = type(entry) == "table" and entry.kind == self.activeTab

            if matches and filters.trade ~= "all" then
                local actualTrade = tostring(entry.tradeType or ""):lower()
                local requestedTrade = tostring(filters.trade):lower()
                if requestedTrade == "kaufe" then
                    matches = actualTrade == "kaufe" or actualTrade == "kauf" or actualTrade == "kaufen"
                else
                    matches = actualTrade == requestedTrade:lower()
                end
            end

            if matches and filters.status == "active" then
                matches = entry.completed ~= true and (tonumber(entry.expiresAt) or 0) > GTC:Now()
            elseif matches and filters.status == "completed" then
                matches = entry.completed == true
            end

            if matches and filters.ownOnly == true and database and database.scopeType == "guild" then
                matches = playerName ~= nil and GTC:SameCharacter(entry.character, playerName)
            end

            if matches and hasQualityFilter then
                matches = U3.QualityMatches(filters.qualities, entry.itemID)
            end

            if matches and searchQuery ~= "" then
                local searchable = table.concat({
                    tostring(entry.item or ""),
                    tostring(entry.itemID or ""),
                    tostring(entry.itemLink or ""),
                    tostring(entry.character or ""),
                    tostring(entry.tradeType or ""),
                    tostring(entry.description or ""),
                    EntryProf(entry) and Prof:Name(EntryProf(entry)) or "",
                }, " "):lower()
                matches = searchable:find(searchQuery, 1, true) ~= nil
            end

            if matches then
                table.insert(filtered, entry)
                seen[entry] = true
            end
        end


        local pageSize = #rows
        local pageCount = math.max(1, math.ceil(#filtered / pageSize))
        listingPageCount = pageCount
        self.currentPage = math.max(1, math.min(self.currentPage or 1, pageCount))

        listTitle:SetText(
            (self.activeTab == "offer" and L("ANGEBOTE") or L("GESUCHE"))
            .. "  |  " .. #filtered .. L(" Einträge")
        )
        pageLabel:SetText(L("SEITE ") .. self.currentPage .. " / " .. pageCount)
        if pageText then
            pageText:SetText(L("Seite ") .. self.currentPage .. " / " .. pageCount)
        end
        self:UpdatePageButtons()
        if #filtered == 0 then
            local filters = U3.listing
            local filtersActive = tostring(filters.search or "") ~= ""
                or filters.trade ~= "all"
                or filters.status ~= "all"
                or next(filters.qualities) ~= nil
                or (filters.ownOnly == true and GTC.db and GTC.db.scopeType == "guild")
            if filtersActive then
                emptyMessage:SetText(L("Keine passenden Inserate gefunden."))
            else
                emptyMessage:SetText(self.activeTab == "offer" and L("Noch keine Angebote vorhanden.") or L("Noch keine Gesuche vorhanden."))
            end
        else
            emptyMessage:SetText(self.activeTab == "offer" and L("Noch keine Angebote vorhanden.") or L("Noch keine Gesuche vorhanden."))
        end
        emptyMessage:SetShown(#filtered == 0)

        for i, row in ipairs(rows) do
            local index = ((self.currentPage - 1) * pageSize) + i
            local entry = filtered[index]

            if entry then
                local entryProf = EntryProf(entry)
                local itemLink = (not entryProf) and ResolveItemLink(entry) or nil
                if entryProf then
                    local info = entry.kind ~= "wanted" and Prof:RecipeInfo(entry) or nil
                    local extra = (info and info.count)
                        and ("  |cff7fd8ff" .. (L("%d Rezepte")):format(info.count) .. "|r") or ""
                    row.name:SetText(Prof:BuildLink(entryProf) .. extra)
                elseif itemLink then
                    row.name:SetText(itemLink .. "  x" .. tostring(entry.quantity))
                else
                    row.name:SetText(tostring(entry.item) .. "  x" .. tostring(entry.quantity))
                end

                if entry.completed == true then
                    row.meta:SetText(
                        "|cff2ecc71ABGESCHLOSSEN|r | " ..
                        tostring(entry.character) .. " | " .. L(tostring(entry.tradeType))
                    )
                else
                    row.meta:SetText(
                        tostring(entry.character) .. " | " ..
                        L(tostring(entry.tradeType)) .. " | " .. FormatRemainingTime(entry)
                    )
                end
                row.description:SetText(tostring(entry.description))

                local texture = entryProf and Prof:Icon(entryProf) or ResolveItemIcon(entry)
                if texture then
                    row.iconTexture:SetTexture(texture)
                    row.iconTexture:Show()
                    row.icon:Hide()
                else
                    row.iconTexture:Hide()
                    row.icon:SetText(self.activeTab == "offer" and "+" or "?")
                    row.icon:Show()
                end

                row.frame:SetScript("OnClick", function()
                    -- Shift-Klick: Item-Link in den Chat, Strg-Klick: Anprobe (wie bei Item-Links im Spiel).
                    if (IsModifiedClick and (IsModifiedClick("CHATLINK") or IsModifiedClick("DRESSUP"))) then
                        local chatLink = ListingChatLink(entry)
                        if chatLink then
                            if type(HandleModifiedItemClick) == "function" then
                                local ok, handled = pcall(HandleModifiedItemClick, chatLink)
                                if ok and handled then
                                    return
                                end
                            end
                            -- Keine Chat-Eingabe offen: Chat mit dem Link oeffnen.
                            if IsModifiedClick("CHATLINK") then
                                if type(ChatFrameUtil) == "table" and type(ChatFrameUtil.OpenChat) == "function" then
                                    ChatFrameUtil.OpenChat(chatLink)
                                    return
                                elseif type(ChatFrame_OpenChat) == "function" then
                                    ChatFrame_OpenChat(chatLink)
                                    return
                                end
                            end
                        end
                    end
                    OpenListing(entry)
                end)

                -- Inhalt der Karte hat sich geaendert, waehrend die Maus darauf liegt
                -- (z. B. Sync oder Blaettern): Tooltip auf das neue Inserat umstellen.
                local previousEntry = row.frame.gtcEntry
                row.frame.gtcEntry = entry
                row.frame:Show()
                if previousEntry ~= entry and GameTooltip:IsOwned(row.frame) then
                    row.frame.gtcTooltipRetries = 0
                    ShowListingItemTooltip(row.frame)
                end
            else
                row.frame.gtcEntry = nil
                if GameTooltip:IsOwned(row.frame) then
                    GameTooltip:Hide()
                end
                row.frame:Hide()
            end
        end
    end

    offers:SetScript("OnClick", function()
        self.activeTab = "offer"
        self.currentPage = 1
        -- Eintragsformular schliessen, sonst liegen Formular und Liste uebereinander.
        formPanel:Hide()
        GTC.itemLinkCaptureActive = false
        detail:Hide()
        listPanel:Show()
        self:RefreshListingView()
    end)

    wanted:SetScript("OnClick", function()
        self.activeTab = "wanted"
        self.currentPage = 1
        formPanel:Hide()
        GTC.itemLinkCaptureActive = false
        detail:Hide()
        listPanel:Show()
        self:RefreshListingView()
    end)


    previous = Button(root, L("< Zurück"), 100, 26)
    previous:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 20, 12)
    previous:SetScript("OnClick", function()
        self.currentPage = math.max(1, self.currentPage - 1)
        self:RefreshListingView()
    end)
    previous:Hide()

    nextPage = Button(root, L("Weiter >"), 100, 26)
    -- Seitenzahl zwischen Zurueck und Weiter.
    pageText = Text(root, "GameFontHighlightSmall", "LEFT", previous, "RIGHT", 8, 0)
    pageText:SetWidth(100)
    pageText:SetJustifyH("CENTER")
    pageText:SetTextColor(unpack(C.muted))
    pageText:Hide()
    nextPage:SetPoint("LEFT", previous, "RIGHT", 116, 0)
    nextPage:SetScript("OnClick", function()
        self.currentPage = math.min(listingPageCount, self.currentPage + 1)
        self:RefreshListingView()
    end)
    nextPage:Hide()

    -- Blaettern-Buttons folgen der Sichtbarkeit der Liste.
    listPanel:HookScript("OnShow", function() self:UpdatePageButtons() end)
    listPanel:HookScript("OnHide", function() self:UpdatePageButtons() end)

    -- Reiter "Rezepte" (Modul Recipes.lua): ersetzt die Listenansicht, solange er aktiv ist.
    local recipePanel
    if type(self.CreateRecipePanel) == "function" then
        recipePanel = self:CreateRecipePanel(root, self.UIKit)
        recipePanel:HookScript("OnShow", function()
            listPanel:Hide()
            detail:Hide()
            formPanel:Hide()
        end)
        local function HideRecipes() recipePanel:Hide() end
        listPanel:HookScript("OnShow", HideRecipes)
        detail:HookScript("OnShow", HideRecipes)
        formPanel:HookScript("OnShow", HideRecipes)
        recipesButton:SetScript("OnClick", function()
            if GTC.Recipes and GTC.Recipes.ClearCrafterFilter then GTC.Recipes:ClearCrafterFilter() end
            recipePanel:Show()
        end)
        self.OpenRecipeTab = function() recipePanel:Show() end
    else
        recipesButton:Hide()
    end

    local close = Button(root, L("Schließen"), 110, 26)
    close:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 12)
    close:SetScript("OnClick", function()
        root:Hide()
    end)

    -- Restzeiten der Inserate alle 30 s aktualisieren: Timer nur solange das
    -- Fenster sichtbar ist (vorher OnUpdate in jedem Frame).
    local listRefreshTicker
    root:HookScript("OnShow", function()
        self:RefreshListingView()
        if listRefreshTicker then listRefreshTicker:Cancel() end
        listRefreshTicker = C_Timer.NewTicker(30, function()
            if root:IsShown() and listPanel:IsShown() then
                self:RefreshListingView()
            end
        end)
    end)
    root:HookScript("OnHide", function()
        if listRefreshTicker then
            listRefreshTicker:Cancel()
            listRefreshTicker = nil
        end
    end)

    -- Minimap-Button fuer den schnellen Zugriff auf das Handelsbrett.
    if Minimap and not self.minimapButton then
        local minimapButton = CreateFrame(
            "Button", "GuildTradeCenterMinimapButton", Minimap
        )
        minimapButton:SetSize(34, 34)
        minimapButton:SetFrameStrata("MEDIUM")
        minimapButton:SetFrameLevel(Minimap:GetFrameLevel() + 8)
        local function PositionMinimapButton(angle)
            local radius = math.min(
                Minimap:GetWidth(),
                Minimap:GetHeight()
            ) / 2 + 8

            minimapButton:ClearAllPoints()
            minimapButton:SetPoint(
                "CENTER",
                Minimap,
                "CENTER",
                math.cos(angle) * radius,
                math.sin(angle) * radius
            )
        end

        local storedAngle = GuildTradeCenterDB
            and tonumber(GuildTradeCenterDB.minimapAngle)
        local minimapAngle = storedAngle or math.pi / 4

        PositionMinimapButton(minimapAngle)

        local UpdateMinimapDrag
        minimapButton:SetMovable(true)
        minimapButton:SetClampedToScreen(true)
        minimapButton:RegisterForDrag("LeftButton")

        minimapButton:SetScript("OnMouseDown", function(button)
            button.wasDragged = false
        end)

        minimapButton:SetScript("OnDragStart", function(button)
            button.isDragging = true
            button:SetScript("OnUpdate", UpdateMinimapDrag)
        end)

        minimapButton:SetScript("OnDragStop", function(button)
            button.isDragging = false
            button:SetScript("OnUpdate", nil)

            if type(GuildTradeCenterDB) ~= "table" then
                GuildTradeCenterDB = {}
            end

            GuildTradeCenterDB.minimapAngle = minimapAngle
            button.wasDragged = true
        end)

        UpdateMinimapDrag = function(button)
            local cursorX, cursorY = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()

            cursorX = cursorX / scale
            cursorY = cursorY / scale

            local centerX, centerY = Minimap:GetCenter()
            if not centerX or not centerY then
                return
            end

            local dx = cursorX - centerX
            local dy = cursorY - centerY

            if dx ~= 0 or dy ~= 0 then
                minimapAngle = math.atan2(dy, dx)
                PositionMinimapButton(minimapAngle)
            end
        end
        minimapButton:RegisterForClicks("LeftButtonUp")

        -- Das Logo ist bereits rund und hat einen eigenen Rand: ohne Blizzard-Rahmen
        -- (der vorher auf 32x32 gestreckt wurde und das Symbol verzerrte).
        local icon = minimapButton:CreateTexture(nil, "ARTWORK")
        icon:SetTexture("Interface\\AddOns\\GuildTradeCenter\\GTC_MinimapIcon_128.png")
        icon:SetAllPoints(minimapButton)

        local glow = minimapButton:CreateTexture(nil, "HIGHLIGHT")
        glow:SetTexture("Interface\\AddOns\\GuildTradeCenter\\GTC_MinimapIcon_128.png")
        glow:SetAllPoints(minimapButton)
        glow:SetBlendMode("ADD")
        glow:SetAlpha(0.35)

        minimapButton:SetScript("OnClick", function(button)
            if button.wasDragged then
                button.wasDragged = false
                return
            end
            if type(GTC.ToggleMainWindow) == "function" then
                GTC:ToggleMainWindow()
            elseif GTC.mainWindow then
                if GTC.mainWindow:IsShown() then
                    GTC.mainWindow:Hide()
                else
                    GTC.mainWindow:Show()
                end
            end
        end)

        minimapButton:SetScript("OnEnter", function(button)
            GameTooltip:SetOwner(button, "ANCHOR_LEFT")
            GameTooltip:AddLine("GuildTradeCenter")
            GameTooltip:AddLine(L("Linksklick: Handelsbrett öffnen"), 1, 1, 1)
            GameTooltip:AddLine(L("Ziehen: Button am Minimap-Rand verschieben"), 0.75, 0.84, 0.97)
            GameTooltip:Show()
        end)

        minimapButton:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        self.minimapButton = minimapButton
    end

    -- CurseForge-Feedback: eigenes Fenster mit sichtbar markierbarem Link.
-- CurseForge-Feedback als interne GTC-Ansicht.
    local feedbackUrl = "https://www.curseforge.com/wow/addons/gtc/comments"

    -- Gemeinsamer Info-/Feedbackbereich fuer den ?-Button.
    local infoFrame
    local RefreshGTCInfo

    local feedbackFrame = CreateFrame("Frame", nil, root, "BackdropTemplate")
    feedbackFrame:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -112)
    feedbackFrame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 48)
    feedbackFrame:SetFrameLevel(
        math.max(
            listPanel:GetFrameLevel(),
            detail:GetFrameLevel(),
            formPanel:GetFrameLevel()
        ) + 5
    )
    feedbackFrame:EnableMouse(true)
    Backdrop(feedbackFrame, C.panel, C.gold)
    feedbackFrame:Hide()

    -- Überschrift
    local feedbackTitle = Text(
        feedbackFrame, "GameFontNormalLarge",
        "TOPLEFT", feedbackFrame, "TOPLEFT", 22, -24
    )
    feedbackTitle:SetText("GTC - Feedback")
    feedbackTitle:SetTextColor(unpack(C.gold))

    -- Kurze Erklärung im Stil des Hauptfensters
    local feedbackDescription = Text(
        feedbackFrame, "GameFontHighlight",
        "TOPLEFT", feedbackFrame, "TOPLEFT", 22, -60
    )
    feedbackDescription:SetWidth(760)
    feedbackDescription:SetText(
        L("Fehler gefunden oder eine Idee? Hier kannst du Feedback zu GuildTradeCenter geben.")
    )

    local feedbackHint = Text(
        feedbackFrame, "GameFontHighlightSmall",
        "TOPLEFT", feedbackFrame, "TOPLEFT", 22, -96
    )
    feedbackHint:SetText(L("Link ist markiert. Mit Strg+C kopieren und im Browser öffnen."))
    feedbackHint:SetTextColor(unpack(C.cyan))

    -- Linkfeld mit GTC-Hintergrund und Rahmen statt Standard-Blizzard-Design
    local feedbackEditBox = CreateFrame(
        "EditBox", nil, feedbackFrame, "BackdropTemplate"
    )
    feedbackEditBox:SetSize(740, 34)
    feedbackEditBox:SetPoint(
        "TOPLEFT", feedbackFrame, "TOPLEFT", 22, -122
    )
    feedbackEditBox:SetAutoFocus(false)
    feedbackEditBox:SetFontObject(GameFontHighlight)
    feedbackEditBox:SetTextColor(unpack(C.cyan))
    feedbackEditBox:SetTextInsets(10, 10, 0, 0)
    feedbackEditBox:SetJustifyH("LEFT")
    Backdrop(feedbackEditBox, C.inputBackground, C.inputBorder)
    feedbackEditBox:SetText(feedbackUrl)

    feedbackEditBox:SetScript("OnEscapePressed", function(box)
        box:ClearFocus()
        feedbackFrame:Hide()
    end)

    feedbackEditBox:SetScript("OnEditFocusGained", function(box)
        box:HighlightText()
    end)

-- Auch der Feedback-Zurueck-Button verwendet den zentralen Helfer.
    local feedbackClose = Button(feedbackFrame, L("Zurück"), 120, 30)
    feedbackClose:SetPoint("BOTTOMRIGHT", feedbackFrame, "BOTTOMRIGHT", -22, 16)
    feedbackClose:SetScript("OnClick", function()
        feedbackEditBox:ClearFocus()
        feedbackFrame:Hide()
        if RefreshGTCInfo then
            RefreshGTCInfo()
        end
        infoFrame:Show()
    end)

-- Kompakter, theme-abhaengiger Feedback-Button neben Schliessen.
    local feedbackButton = Button(root, "?", 26, 26)

    if root.CloseButton then
        feedbackButton:SetPoint("RIGHT", root.CloseButton, "LEFT", -6, 0)
    else
        feedbackButton:SetPoint("TOPRIGHT", root, "TOPRIGHT", -46, -4)
    end
    feedbackButton:SetScript("OnClick", function()
        if infoFrame:IsShown() or feedbackFrame:IsShown() then
            feedbackEditBox:ClearFocus()
            infoFrame:Hide()
            feedbackFrame:Hide()
        else
            if RefreshGTCInfo then
                RefreshGTCInfo()
            end
            infoFrame:Show()
        end
    end)

    feedbackButton:SetScript("OnEnter", function(button)
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText("GTC Info & Status")
        GameTooltip:AddLine(
            L("Version, Scan-Status und Feedback anzeigen."),
            1, 1, 1, true
        )
        GameTooltip:Show()
    end)

    feedbackButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    feedbackFrame:SetScript("OnShow", function()
        feedbackEditBox:SetText(feedbackUrl)
        feedbackEditBox:SetFocus()
        feedbackEditBox:HighlightText()
    end)

    feedbackFrame:SetScript("OnHide", function()
        feedbackEditBox:ClearFocus()
    end)

    -- --------------------------------------------------------
    -- GTC Info & Status
    -- Die lokalen Scan-Zeitpunkte stammen aus der bestehenden
    -- Scanner-Logik. Es werden hier keine Scans gestartet.
    -- --------------------------------------------------------

    infoFrame = CreateFrame("Frame", nil, root, "BackdropTemplate")
    infoFrame:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -112)
    infoFrame:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", -20, 48)
    infoFrame:SetFrameLevel(
        math.max(
            feedbackFrame:GetFrameLevel(),
            listPanel:GetFrameLevel(),
            detail:GetFrameLevel(),
            formPanel:GetFrameLevel()
        ) + 10
    )
    infoFrame:EnableMouse(true)
    Backdrop(infoFrame, C.panel, C.gold)
    infoFrame:Hide()

    local infoTitle = Text(
        infoFrame, "GameFontNormalLarge",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -24
    )
    infoTitle:SetText("GTC - Info & Status")
    infoTitle:SetTextColor(unpack(C.gold))

    local infoVersionText = Text(
        infoFrame, "GameFontHighlight",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -58
    )
    infoVersionText:SetTextColor(unpack(C.cyan))

    local infoThemeText = Text(
        infoFrame, "GameFontHighlight",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -84
    )

    local infoScopeText = Text(
        infoFrame, "GameFontHighlightSmall",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -110
    )
    infoScopeText:SetTextColor(unpack(C.muted))
    infoScopeText:SetWidth(790)
    infoScopeText:SetWordWrap(true)

    local infoAutoScanText = Text(
        infoFrame, "GameFontHighlight",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -145
    )
    infoAutoScanText:SetWidth(790)
    infoAutoScanText:SetWordWrap(true)

    local infoInventoryText = Text(
        infoFrame, "GameFontHighlight",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -194
    )

    local infoBankText = Text(
        infoFrame, "GameFontHighlight",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -220
    )

    local infoSlotsText = Text(
        infoFrame, "GameFontHighlightSmall",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -246
    )
    infoSlotsText:SetTextColor(unpack(C.muted))

    local infoRecommendation = Text(
        infoFrame, "GameFontHighlight",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -282
    )
    infoRecommendation:SetWidth(790)
    infoRecommendation:SetWordWrap(true)
    infoRecommendation:SetJustifyH("LEFT")

    -- GTC_UPDATE4_SCAN_SYNC_MONITOR
    local infoLiveStatus = Text(
        infoFrame, "GameFontHighlightSmall",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -318
    )
    infoLiveStatus:SetWidth(790)
    infoLiveStatus:SetWordWrap(true)
    infoLiveStatus:SetJustifyH("LEFT")

    local infoSyncMonitorText = Text(
        infoFrame, "GameFontHighlightSmall",
        "TOPLEFT", infoFrame, "TOPLEFT", 22, -352
    )
    infoSyncMonitorText:SetWidth(790)
    infoSyncMonitorText:SetWordWrap(true)
    infoSyncMonitorText:SetJustifyH("LEFT")

    local function GTCUpdate4CountTableEntries(value)
        local count = 0
        if type(value) == "table" then
            for _ in pairs(value) do count = count + 1 end
        end
        return count
    end

    local infoSyncNote = Text(
        infoFrame, "GameFontHighlightSmall",
        "BOTTOMLEFT", infoFrame, "BOTTOMLEFT", 22, 55
    )
    infoSyncNote:SetWidth(790)
    infoSyncNote:SetWordWrap(true)
    infoSyncNote:SetText(
        L("Hinweis: Ein lokaler Inventar-/Bankscan ist kein Nachweis für einen erfolgreichen Gilden-Sync.")
    )
    infoSyncNote:SetTextColor(unpack(C.muted))

    local function FormatScanTimestamp(timestamp)
        timestamp = tonumber(timestamp)

        if not timestamp or timestamp <= 0 then
            return L("Noch nicht erfasst")
        end

        return date("%d.%m.%Y %H:%M", timestamp)
    end

    RefreshGTCInfo = function()
        infoVersionText:SetText(
            "Version: " .. tostring(GTC.version or "unbekannt")
        )

        infoThemeText:SetText(
            L("Aktives Design: ") .. tostring(C.label or activeThemeKey)
        )

        local db = GTC.db
        local scopeText = L("Datenbereich: noch nicht verfügbar")

        if type(db) == "table" then
            local scopeType = tostring(db.scopeType or "lokal")

            if scopeType == "guild" then
                scopeText = L("Datenbereich: Gilde - ") ..
                    tostring(db.guildName or L("Gilde nicht erkannt"))
            else
                scopeText = L("Datenbereich: ") .. scopeType
            end

            if db.realm then
                scopeText = scopeText .. " | Realm: " .. tostring(db.realm)
            end
        end

        infoScopeText:SetText(scopeText)

        infoAutoScanText:SetText(
            L("Automatische Auslöser: Login, Taschen-Änderungen, ") ..
            L("Öffnen der Bank und Änderungen an Bankslots.")
        )

        local scan = nil

        if type(db) == "table" and type(db.scan) == "table" then
            scan = db.scan
        end

        local inventoryStamp = tonumber(scan and scan.inventoryLastScan)
        local bankStamp = tonumber(scan and scan.bankLastScan)
        local visitedSlots = tonumber(scan and scan.lastVisitedSlots)

        infoInventoryText:SetText(
            L("Letzter Inventarscan: ") ..
            FormatScanTimestamp(inventoryStamp)
        )

        infoBankText:SetText(
            L("Letzter Bankscan: ") ..
            FormatScanTimestamp(bankStamp)
        )

        infoSlotsText:SetText(
            L("Zuletzt geprüfte Slots: ") ..
            (visitedSlots and tostring(visitedSlots) or "unbekannt")
        )

        local recommendation

        if not inventoryStamp then
            recommendation =
                L("Empfehlung: Es ist kein erfolgreicher Inventarscan protokolliert. Ein Scan ist sinnvoll.")
        else
            local age = time() - inventoryStamp

            if age < 0 then
                age = 0
            end

            if age >= 86400 then
                recommendation =
                    L("Empfehlung: Der letzte Inventarscan ist mindestens 24 Stunden alt. Eine manuelle Prüfung kann sinnvoll sein.")
            elseif not bankStamp then
                recommendation =
                    L("Empfehlung: Inventardaten sind vorhanden. Ein Bankscan wird beim nächsten Öffnen der Bank automatisch angestoßen.")
            else
                recommendation =
                    L("Empfehlung: Scan-Zeitpunkte sind vorhanden. Login-, Taschen- und Bankereignisse lösen weiterhin automatische Scans aus. Ein zusätzlicher Scan ist anhand dieser Daten derzeit nicht erkennbar.")
            end
        end

        infoRecommendation:SetText(recommendation)

        local latestStatus = tostring(GTC.windowStatusMessage or "")
        if latestStatus == "" then
            latestStatus = L("Noch keine Laufzeit-Statusmeldung vorhanden.")
        end
        infoLiveStatus:SetText(L("Letzter GTC-Laufzeitstatus: ") .. latestStatus)

        local sync = type(db) == "table" and type(db.sync) == "table" and db.sync or {}
        local peers = GTCUpdate4CountTableEntries(sync.peers)
        local pendingItems = tonumber(sync.pendingItemCount)
        if pendingItems == nil then pendingItems = GTCUpdate4CountTableEntries(sync.pendingItems) end
        local pendingListings = tonumber(sync.pendingListingCount)
        if pendingListings == nil then pendingListings = GTCUpdate4CountTableEntries(sync.pendingListings) end
        local lastSync = tonumber(sync.lastSync) or 0
        local syncStatus
        local inGuildKnown = type(IsInGuild) == "function"
        local inGuild = inGuildKnown and IsInGuild() == true

        if type(db) ~= "table" then
            syncStatus = L("Gilden-Sync: Status nicht verfügbar, weil die lokale Datenbank noch nicht bereit ist.")
        elseif not inGuildKnown then
            syncStatus = L("Gilden-Sync: Status nicht verfügbar; die Gildenmitgliedschaft konnte nicht geprüft werden.")
        elseif not inGuild then
            syncStatus = L("Gilden-Sync: Keine Gilde erkannt.")
        elseif tostring(db.scopeType or "personal") ~= "guild" then
            syncStatus = L("Gilden-Sync: Nicht aktiv - der persönliche Datenbereich ist ausgewählt.")
        else
            local guildName = tostring(db.guildName or L("Gilde nicht erkannt"))
            if lastSync > 0 then
                syncStatus = L("Gilden-Sync für ") .. guildName .. L(": letzter erfolgreicher Snapshot-Empfang ") .. FormatScanTimestamp(lastSync) .. "."
            else
                syncStatus = L("Gilden-Sync für ") .. guildName .. L(": noch keine erfolgreiche Sync-Aktualisierung empfangen.")
            end
            syncStatus = syncStatus .. L(" Bekannte Peers: ") .. tostring(peers)
                .. L(" | wartende Item-Datensätze: ") .. tostring(pendingItems)
                .. L(" | wartende Inserate: ") .. tostring(pendingListings) .. "."
        end
        infoSyncMonitorText:SetText(syncStatus)
    end

    local infoRefreshButton = Button(
        infoFrame, L("Status aktualisieren"), 170, 30
    )
    infoRefreshButton:SetPoint(
        "BOTTOMLEFT", infoFrame, "BOTTOMLEFT", 22, 16
    )
    infoRefreshButton:SetScript("OnClick", function()
        if RefreshGTCInfo then
            RefreshGTCInfo()
        end
    end)

    local infoFeedbackButton = Button(
        infoFrame, "Feedback & CurseForge", 190, 30
    )
    infoFeedbackButton:SetPoint(
        "BOTTOMRIGHT", infoFrame, "BOTTOMRIGHT", -22, 16
    )
    infoFeedbackButton:SetScript("OnClick", function()
        infoFrame:Hide()
        feedbackFrame:Show()
    end)

    infoFrame:SetScript("OnShow", function()
        if RefreshGTCInfo then
            RefreshGTCInfo()
        end
    end)

    local update4MonitorElapsed = 0
    infoFrame:SetScript("OnUpdate", function(_, elapsed)
        update4MonitorElapsed = update4MonitorElapsed + elapsed
        if update4MonitorElapsed < 1.5 then return end
        update4MonitorElapsed = 0
        if infoFrame:IsShown() and RefreshGTCInfo then
            RefreshGTCInfo()
        end
    end)
    -- Info- und Feedback-Ansicht beim Schliessen zuruecksetzen.
    root:HookScript("OnHide", function()
        feedbackFrame:Hide()
        infoFrame:Hide()
        -- Der Katalog-Dialog haengt an UIParent und blieb sonst offen (auch nach
        -- einem Designwechsel als verwaistes Fenster).
        itemCatalogFrame:Hide()
    end)

    -- Info/Feedback liegen ueber dem Inhaltsbereich. Ein Klick auf einen der Reiter muss sie
    -- schliessen, sonst bleibt man in der Info-Ansicht haengen.
    local function CloseInfoViews()
        feedbackEditBox:ClearFocus()
        infoFrame:Hide()
        feedbackFrame:Hide()
    end
    offers:HookScript("OnClick", CloseInfoViews)
    wanted:HookScript("OnClick", CloseInfoViews)
    createEntry:HookScript("OnClick", CloseInfoViews)
    recipesButton:HookScript("OnClick", CloseInfoViews)

    self.mainWindow = root
    self:RefreshListingView()
end

function GTC:ShowRecipes()
    if not self.mainWindow then
        self:CreateMainWindow()
    end
    if not self.mainWindow:IsShown() then
        self:RefreshListingView()
        self.mainWindow:Show()
    end
    if self.Recipes and self.Recipes.ClearCrafterFilter then
        self.Recipes:ClearCrafterFilter()
    end
    if self.OpenRecipeTab then
        self.OpenRecipeTab()
    end
end

function GTC:ToggleMainWindow()
    if not self.mainWindow then
        self:CreateMainWindow()
    end

    if self.mainWindow:IsShown() then
        self.mainWindow:Hide()
    else
        self:RefreshListingView()
        self.mainWindow:Show()
    end
end

-- GTC_AUCTION_TOOLTIP_UPDATE2
-- WoW Forever 1.60.1 uses a tooltip poll driver; do not rely only on OnTooltipSetItem.
if GTC and not GTC._gtcAuctionTooltipHookInstalled
    and GameTooltip and type(GameTooltip.HookScript) == "function" then

    local gtcAuctionTooltip = GameTooltip
    local gtcAuctionLastItemLink = nil

    local function GTCUpdate2CountActiveListings(itemID, db)
        local offers = 0
        local wanted = 0
        local now = GTC:Now()
        local activeScopeKey = db.scopeKey

        for _, entry in ipairs(db.listings) do
            if type(entry) == "table"
                and tonumber(entry.itemID) == itemID
                and entry.isTest == false
                and entry.completed ~= true
                and (tonumber(entry.expiresAt) or 0) > now
                and (type(activeScopeKey) ~= "string"
                    or entry.scopeKey == nil
                    or entry.scopeKey == activeScopeKey) then

                if entry.kind == "offer" then
                    offers = offers + 1
                elseif entry.kind == "wanted" then
                    wanted = wanted + 1
                end
            end
        end

        return offers, wanted
    end

    local function GTCUpdate2RefreshItemTooltip()
        if not gtcAuctionTooltip:IsShown() then
            gtcAuctionLastItemLink = nil
            return
        end

        if type(gtcAuctionTooltip.GetItem) ~= "function" then
            return
        end

        local ok, _, itemLink = pcall(gtcAuctionTooltip.GetItem, gtcAuctionTooltip)
        if not ok or type(itemLink) ~= "string" then
            gtcAuctionLastItemLink = nil
            return
        end

        local itemID = tonumber(itemLink:match("|[Hh]item:(%d+)"))
            or tonumber(itemLink:match("^item:(%d+)"))
        if not itemID then
            gtcAuctionLastItemLink = nil
            return
        end

        local db = GTC and GTC.db
        if type(db) ~= "table" or type(db.listings) ~= "table" then
            return
        end

        -- One render per current hyperlink. Setter hooks and hide/show reset this
        -- key, including when the same item is hovered again without a hide gap.
        if gtcAuctionLastItemLink == itemLink then
            return
        end

        local offerCount, wantedCount = GTCUpdate2CountActiveListings(itemID, db)
        gtcAuctionLastItemLink = itemLink

        gtcAuctionTooltip:AddLine(
            "|cff35d0d0GTC|r  Angebote: " .. tostring(offerCount)
                .. L("  |  Gesuche: ") .. tostring(wantedCount),
            0.90, 0.92, 0.94, false
        )
        gtcAuctionTooltip:Show()
    end

    gtcAuctionTooltip:HookScript("OnShow", function()
        gtcAuctionLastItemLink = nil
    end)
    gtcAuctionTooltip:HookScript("OnHide", function()
        gtcAuctionLastItemLink = nil
    end)

    -- In the Forever/Mainline tooltip path, OnUpdate is the reliable render
    -- driver. We only scan listings when the displayed item/link changes.
    -- Wie im Original: Poll in jedem Frame (nur solange der Tooltip sichtbar ist). Eine
    -- Drosselung oder zusaetzliche Tooltip-Hooks liessen die GTC-Zeile verzoegert
    -- erscheinen und den Tooltip ruckeln.
    gtcAuctionTooltip:HookScript("OnUpdate", GTCUpdate2RefreshItemTooltip)

    -- Some item sources can replace the tooltip contents without hiding it.
    -- Feature-detect methods so this remains compatible with the active client.
    if type(hooksecurefunc) == "function" then
        local itemTooltipSetters = {
            "SetHyperlink",
            "SetItemByID",
            "SetBagItem",
            "SetInventoryItem",
            "SetInventoryItemByID",
            "SetMerchantItem",
            "SetLootItem",
            "SetLootRollItem",
            "SetGuildBankItem",
            "SetInboxItem",
            "SetBuybackItem",
            "SetSendMailItem",
            "SetTradePlayerItem",
            "SetTradeTargetItem",
            "SetQuestItem",
            "SetAuctionItem",
            "SetSocketGem",
            "SetExistingSocketGem",
        }

        for _, methodName in ipairs(itemTooltipSetters) do
            if type(gtcAuctionTooltip[methodName]) == "function" then
                pcall(hooksecurefunc, gtcAuctionTooltip, methodName, function()
                    gtcAuctionLastItemLink = nil
                end)
            end
        end
    end

    GTC._gtcAuctionTooltipHookInstalled = true
end
-- GTC_UPDATE3_QUALITY_EVENT_GUARD
-- Nur Items, die bereits im GTC-Katalog oder in Inseraten vorkommen, loesen UI-Refreshes aus.
if not GTC._update3QualityEventFrame then
    local update3EventFrame = CreateFrame("Frame")
    pcall(update3EventFrame.RegisterEvent, update3EventFrame, "GET_ITEM_INFO_RECEIVED")
    pcall(update3EventFrame.RegisterEvent, update3EventFrame, "ITEM_DATA_LOAD_RESULT")
    update3EventFrame:SetScript("OnEvent", function(_, event, loadedItemID, succeeded)
        local itemID = tonumber(loadedItemID)
        if not itemID then return end
        local key = tostring(itemID)
        local state = GTC._update3State
        if state and state.pendingQualityRequests then state.pendingQualityRequests[key] = nil end

        -- Nur arbeiten, wenn eine GTC-Ansicht offen ist. Dieses Ereignis feuert fuer JEDES
        -- Item im Spiel (Tooltips, Taschen, andere Addons).
        local mainShown = GTC.mainWindow and GTC.mainWindow:IsShown()
        local catalogShown = type(GTC.IsItemCatalogShown) == "function" and GTC.IsItemCatalogShown()
        if not mainShown and not catalogShown then return end

        local db = GTC.db
        if type(db) ~= "table" then return end
        local items = type(db.items) == "table" and db.items or {}
        local record = items[key]
        local tracked = type(record) == "table"
        if not tracked and type(db.listings) == "table" then
            for _, listing in ipairs(db.listings) do
                if type(listing) == "table" and tonumber(listing.itemID) == itemID then
                    tracked = true
                    break
                end
            end
        end
        if not tracked or succeeded == false then return end

        -- Qualitaet sofort nachtragen (billig), die Neuaufbauten dagegen buendeln.
        if type(record) == "table" and tonumber(record.quality) == nil
            and C_Item and type(C_Item.GetItemInfo) == "function"
            and type(GTC.UpdateItemMetadata) == "function" then
            local ok, itemName, itemLink, quality = pcall(C_Item.GetItemInfo, itemID)
            if ok and type(quality) == "number" then GTC:UpdateItemMetadata(itemID) end
        end

        ScheduleRefresh("itemLoad", 0.3, function()
            if type(GTC.RefreshItemCatalog) == "function" then pcall(GTC.RefreshItemCatalog) end
            if type(GTC.RefreshListingView) == "function" then pcall(GTC.RefreshListingView, GTC) end
        end)
    end)
    GTC._update3QualityEventFrame = update3EventFrame
end