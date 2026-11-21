-- GTC_UPDATE5_AH_SCAN
-- Catalog-only Auction House scan for GuildTradeCenter.
-- Deliberately does not persist auction prices, auction counts or quantities.

local GTC = _G.GuildTradeCenter
if type(GTC) ~= "table" then
    return
end
local L = GTC.T

if type(GTC.AHScan) == "table" and GTC.AHScan.update5Marker == true then
    return
end

local API_COOLDOWN = 15 * 60
local SCAN_BATCH_SIZE = 80
local SCAN_BATCH_DELAY = 0.05
local ROWS_PER_PAGE = 9

local C = {
    background = { 0.035, 0.047, 0.066, 0.99 },
    panel = { 0.066, 0.082, 0.105, 0.98 },
    card = { 0.085, 0.105, 0.13, 0.98 },
    row = { 0.055, 0.071, 0.09, 0.98 },
    gold = { 0.95, 0.70, 0.29, 1 },
    cyan = { 0.25, 0.83, 0.82, 1 },
    text = { 0.88, 0.91, 0.94, 1 },
    muted = { 0.53, 0.60, 0.67, 1 },
    green = { 0.38, 0.83, 0.62, 1 },
    red = { 0.96, 0.40, 0.36, 1 },
}

local state = {
    update5Marker = true,
    awaitingReplication = false,
    running = false,
    requestToken = 0,
    lastRequestAt = 0,
    progress = 0,
    status = "Bereit für den Katalogscan.",
    scannedIDs = {},
    newIDs = {},
    pendingScannedIDs = {},
    pendingNewIDs = {},
    pendingItemData = {},
    seenThisScan = {},
    commitMode = false,
    commitIndex = 1,
    commitErrors = 0,
    pendingMetadata = {},
    processed = 0,
    total = 0,
    uiElapsed = 0,
    window = nil,
    tab = nil,
    ahFrame = nil,
    lists = {},
}
GTC.AHScan = state

local function SetBackdrop(frame, bgColor, borderColor)
    if not frame or type(frame.SetBackdrop) ~= "function" then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(unpack(bgColor or C.panel))
    frame:SetBackdropBorderColor(unpack(borderColor or C.gold))
end

local function MakeText(parent, font, point, relative, relativePoint, x, y, width)
    local text = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    text:SetPoint(point, relative or parent, relativePoint or point, x or 0, y or 0)
    if width then text:SetWidth(width) end
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)
    return text
end

local BUTTON_TIPS = {
    ["< ZURÜCK"] = { "Vorherige Seite", "Blättert in dieser Liste eine Seite zurück." },
    ["WEITER >"] = { "Nächste Seite", "Blättert in dieser Liste eine Seite weiter." },
    ["SCHLIESSEN"] = { "Schließen", "Schließt das Scan-Fenster." },
    ["SCAN STARTEN"] = { "Katalogscan starten", "Liest die Item-Liste des Auktionshauses und ergänzt den GTC-Katalog. Es werden keine Preise gespeichert. Der Katalog wird nicht automatisch geteilt; Mitglieder holen ihn per Knopf Von Gilde laden im Katalog-Dialog. Wegen einer Sperre des Spiels höchstens alle 15 Minuten möglich." },
    ["ABBRECHEN"] = { "Scan abbrechen", "Bricht den Scan ab, solange er die Auktionshaus-Liste liest. Ist die Übernahme in den Katalog schon gestartet, läuft sie sicher zu Ende. Der letzte erfolgreiche Scan bleibt erhalten." },
}

local function MakeButton(parent, label, width, height, accent)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, height)
    button:SetFrameLevel((parent:GetFrameLevel() or 1) + 2)
    SetBackdrop(button, C.card, accent or C.gold)

    local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", button, "CENTER", 0, 0)
    text:SetText(label)
    text:SetTextColor(unpack(accent or C.gold))
    button.label = text

    button:SetScript("OnEnter", function(self)
        SetBackdrop(self, C.row, C.cyan)
        self.label:SetTextColor(unpack(C.cyan))
    end)
    button:SetScript("OnLeave", function(self)
        SetBackdrop(self, C.card, accent or C.gold)
        if self:IsEnabled() then
            self.label:SetTextColor(unpack(accent or C.gold))
        end
    end)
    button:SetScript("OnDisable", function(self)
        self.label:SetTextColor(unpack(C.muted))
        SetBackdrop(self, C.panel, C.muted)
    end)
    button:SetScript("OnEnable", function(self)
        self.label:SetTextColor(unpack(accent or C.gold))
        SetBackdrop(self, C.card, accent or C.gold)
    end)

    local tip = BUTTON_TIPS[GTC.Untranslate(label)]
    if tip then
        button:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(L(tip[1]), 1, 1, 1)
            GameTooltip:AddLine(L(tip[2]), 0.75, 0.84, 0.97, true)
            GameTooltip:Show()
        end)
        button:HookScript("OnLeave", function() GameTooltip:Hide() end)
    end
    return button
end

local function IsItemLink(link)
    return type(link) == "string" and link:match("|[Hh]item:(%d+)") ~= nil
end

local function MakeItemLink(itemID, name)
    local safeName = type(name) == "string" and name ~= "" and name or ("Item #" .. tostring(itemID))
    return "|cffffffff|Hitem:" .. tostring(itemID) .. "|h[" .. safeName .. "]|h|r"
end

local function GetDB()
    local db = GTC.db
    if type(db) ~= "table" or type(db.items) ~= "table" then
        return nil
    end
    if type(db.scan) ~= "table" then
        db.scan = {}
    end
    return db
end

local function GetLatestScan(db)
    if type(db) ~= "table" or type(db.scan) ~= "table" then
        return nil
    end
    local record = db.scan.ahLatestScan
    if type(record) ~= "table" then
        return nil
    end
    local at = tonumber(record.at)
    local character = type(record.character) == "string" and record.character or nil
    if not at or at <= 0 or not character or character == "" then
        return nil
    end
    return record
end

local function FormatTime(timestamp)
    if type(date) == "function" then
        local ok, result = pcall(date, "%d.%m.%Y  %H:%M", timestamp)
        if ok and type(result) == "string" then
            return result
        end
    end
    return tostring(timestamp)
end

local function CurrentPlayerName()
    if type(UnitName) == "function" then
        return UnitName("player") or L("Unbekannt")
    end
    return L("Unbekannt")
end

local function SetStatus(message, isError)
    state.status = tostring(message or "")
    if state.statusText then
        state.statusText:SetText(state.status)
        state.statusText:SetTextColor(unpack(isError and C.red or C.muted))
    end
    if type(GTC.SetWindowStatus) == "function" then
        pcall(GTC.SetWindowStatus, GTC, "GTC Scan: " .. state.status)
    end
end

local function RefreshHeader()
    local db = GetDB()
    if not state.lastScanText then return end

    local latest = GetLatestScan(db)
    if not latest then
        state.lastScanText:SetText(L("Noch kein erfolgreicher GTC-AH-Scan gespeichert."))
        state.lastScanText:SetTextColor(unpack(C.muted))
    else
        local line1 = FormatTime(tonumber(latest.at) or 0)
        local line2
        if latest.character == CurrentPlayerName() then
            line2 = latest.character .. L("  |  Dein lokaler AH-Scan")
        else
            line2 = latest.character .. L("  |  Gildenmitglied-Scan (synchronisiert)")
        end
        state.lastScanText:SetText(line1 .. "\n" .. line2)
        state.lastScanText:SetTextColor(unpack(C.text))
    end

    if state.statusText then
        state.statusText:SetText(L(state.status))
    end
    if state.progressText then
        state.progressText:SetText(tostring(math.floor((state.progress or 0) * 100)) .. "%")
    end
    if state.progressBar then
        state.progressBar:SetValue(math.max(0, math.min(1, state.progress or 0)))
    end
end

local function ReadItemInfo(itemID)
    if C_Item and type(C_Item.GetItemInfo) == "function" then
        return C_Item.GetItemInfo(itemID)
    end
    if type(GetItemInfo) == "function" then
        return GetItemInfo(itemID)
    end
    return nil
end

local function RequestItemInfo(itemID)
    if C_Item and type(C_Item.RequestLoadItemDataByID) == "function" then
        pcall(C_Item.RequestLoadItemDataByID, itemID)
    elseif C_Item and type(C_Item.RequestLoadItemData) == "function" then
        pcall(C_Item.RequestLoadItemData, itemID)
    end
end

local function TouchMetadataForSync(itemID)
    if type(GTC.UpdateItemMetadata) == "function" then
        local ok, changed = pcall(GTC.UpdateItemMetadata, GTC, itemID)
        return ok and changed ~= false
    end
    return false
end

local function RememberCatalogItem(itemID, itemName, itemIcon, itemQuality, itemLink)
    local db = GetDB()
    if not db then
        return false, false
    end

    local key = tostring(itemID)
    local existing = db.items[key]
    local wasNew = type(existing) ~= "table"
    local oldLink = type(existing) == "table" and existing.itemLink or nil
    local oldName = type(existing) == "table" and existing.name or nil
    local link = IsItemLink(itemLink) and itemLink or nil

    if not link and IsItemLink(oldLink) then
        link = oldLink
    end
    if not link then
        link = MakeItemLink(itemID, itemName or oldName)
    end

    local needsBaseData = wasNew
        or not IsItemLink(oldLink)
        or type(oldName) ~= "string"
        or oldName == ""

    if needsBaseData and type(GTC.RememberItem) == "function" then
        local ok, remembered = pcall(GTC.RememberItem, GTC, link)
        if not ok or remembered == false then
            return false, false
        end
    end

    db = GetDB()
    if not db then return false, false end
    local entry = db.items[key]
    if type(entry) ~= "table" then return false, false end

    local apiChanged = false
    if type(itemName) == "string" and itemName ~= "" then
        if not entry.name or entry.name == ("Item #" .. tostring(itemID)) then
            entry.name = itemName
            apiChanged = true
        end
    end
    if (type(itemIcon) == "number" or type(itemIcon) == "string") and not entry.icon then
        entry.icon = itemIcon
        apiChanged = true
    end
    if type(itemQuality) == "number" and itemQuality >= 0 and not tonumber(entry.quality) then
        entry.quality = itemQuality
        apiChanged = true
    end
    if IsItemLink(itemLink) and not IsItemLink(entry.itemLink) then
        entry.itemLink = itemLink
        apiChanged = true
    end

    local missingMetadata = not entry.name or not IsItemLink(entry.itemLink)
        or not entry.icon or not tonumber(entry.quality)
        or not entry.itemType or not entry.itemSubType

    if apiChanged or missingMetadata then
        TouchMetadataForSync(itemID)
    end

    entry = db.items[key]
    if type(entry) == "table" then
        local name = entry.name or itemName
        if not name or name == "" then name = "Item #" .. tostring(itemID) end
        state.pendingMetadata[key] = (not IsItemLink(entry.itemLink) or not entry.name
            or not entry.icon or not tonumber(entry.quality)) and true or nil
        if state.pendingMetadata[key] then
            RequestItemInfo(itemID)
        end
    end

    return true, wasNew
end

local function BuildItemLabel(itemID)
    local db = GetDB()
    local entry = db and db.items[tostring(itemID)] or nil
    if type(entry) ~= "table" then
        return "Item #" .. tostring(itemID), tostring(itemID), nil, nil
    end
    local name = type(entry.name) == "string" and entry.name or ("Item #" .. tostring(itemID))
    return name, tostring(itemID), entry.icon, entry.itemLink
end

local function MatchesSearch(itemID, query)
    if not query or query == "" then return true end
    local name = BuildItemLabel(itemID)
    return tostring(name):lower():find(query, 1, true) ~= nil
        or tostring(itemID):find(query, 1, true) ~= nil
end

-- Item-Kategorien wie im Auktionshaus (Item-Klassen). Die Klasse stammt aus
-- GetItemInfoInstant und braucht keinen geladenen Item-Cache.
local AH_CLASS_ORDER = { 2, 4, 1, 0, 7, 3, 8, 9, 16, 6, 11, 12, 15, 17, 19, 5, 13 }
local classCache = {}

local function ClassOf(itemID)
    local key = tonumber(itemID)
    if not key then return nil end
    local cached = classCache[key]
    if cached ~= nil then
        return cached or nil
    end

    local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    local classID
    if type(info) == "function" then
        local ok, _, _, _, _, _, id = pcall(info, key)
        if ok and type(id) == "number" then
            classID = id
        end
    end
    classCache[key] = classID or false
    return classID
end

local function CategoryName(classID)
    local name = type(GetItemClassInfo) == "function" and GetItemClassInfo(classID) or nil
    if type(name) ~= "string" or name == "" then
        name = L("Kategorie ") .. tostring(classID)
    end
    return name
end

-- Liefert die vorhandenen Kategorien (in Auktionshaus-Reihenfolge) mit Anzahl.
local function CollectCategories(source)
    local counts = {}
    for _, itemID in ipairs(source or {}) do
        local id = ClassOf(itemID)
        if id then
            counts[id] = (counts[id] or 0) + 1
        end
    end

    local ordered, used = {}, {}
    for _, id in ipairs(AH_CLASS_ORDER) do
        if counts[id] then
            ordered[#ordered + 1] = id
            used[id] = true
        end
    end

    local rest = {}
    for id in pairs(counts) do
        if not used[id] then rest[#rest + 1] = id end
    end
    table.sort(rest)
    for _, id in ipairs(rest) do
        ordered[#ordered + 1] = id
    end

    return ordered, counts
end

local RenderList

local function CreateListPanel(parent, title, subtitle, point, x)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetSize(422, 438)
    panel:SetPoint(point, parent, point, x, -174)
    SetBackdrop(panel, C.panel, C.gold)

    local heading = MakeText(panel, "GameFontNormalLarge", "TOPLEFT", panel, "TOPLEFT", 14, -12, 390)
    heading:SetText(title)
    heading:SetTextColor(unpack(C.gold))

    local subheading = MakeText(panel, "GameFontHighlightSmall", "TOPLEFT", panel, "TOPLEFT", 14, -34, 390)
    subheading:SetText(subtitle)
    subheading:SetTextColor(unpack(C.muted))

    local search = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    search:SetSize(250, 24)
    search:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -58)
    search:SetAutoFocus(false)
    search:SetTextInsets(8, 8, 0, 0)
    search:SetFontObject(GameFontHighlightSmall)
    search:SetText("")

    local rows = {}
    for i = 1, ROWS_PER_PAGE do
        local row = CreateFrame("Button", nil, panel, "BackdropTemplate")
        row:SetSize(390, 32)
        row:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -88 - ((i - 1) * 34))
        SetBackdrop(row, C.row, C.panel)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(24, 24)
        icon:SetPoint("LEFT", row, "LEFT", 5, 0)
        icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")

        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 7, 3)
        label:SetWidth(285)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)

        local itemKey = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        itemKey:SetPoint("RIGHT", row, "RIGHT", -7, -7)
        itemKey:SetJustifyH("RIGHT")

        row.iconTexture = icon
        row.nameText = label
        row.idText = itemKey
        row:Hide()
        row:SetScript("OnEnter", function(self)
            if self.itemLink and IsItemLink(self.itemLink) then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(self.itemLink)
                GameTooltip:Show()
            end
            SetBackdrop(self, C.card, C.cyan)
        end)
        row:SetScript("OnLeave", function(self)
            GameTooltip:Hide()
            SetBackdrop(self, C.row, C.panel)
        end)
        table.insert(rows, row)
    end

    local previous = MakeButton(panel, L("< ZURÜCK"), 112, 26, C.muted)
    previous:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 14, 10)
    local nextPage = MakeButton(panel, L("WEITER >"), 112, 26, C.cyan)
    nextPage:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -14, 10)

    local controller = {
        panel = panel,
        search = search,
        rows = rows,
        page = 1,
        title = title,
        source = {},
        filtered = {},
        previous = previous,
        nextPage = nextPage,
    }
    state.lists[#state.lists + 1] = controller

    -- Seitenzahl zwischen Zurueck und Weiter.
    local pageText = MakeText(panel, "GameFontHighlightSmall", "BOTTOM", panel, "BOTTOM", 0, 17, 120)
    pageText:SetJustifyH("CENTER")
    pageText:SetTextColor(unpack(C.muted))
    controller.pageText = pageText

    -- Kategorie-Filter (Item-Klassen wie im Auktionshaus).
    local categoryButton = MakeButton(panel, L("Alle Kategorien"), 138, 24, C.cyan)
    categoryButton:SetPoint("LEFT", search, "RIGHT", 8, 0)
    categoryButton.label:SetWidth(122)
    categoryButton.label:SetWordWrap(false)
    categoryButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(L("Kategorie"), 1, 1, 1)
        GameTooltip:AddLine(L("Filtert die Liste nach Item-Kategorie wie im Auktionshaus."), 0.75, 0.84, 0.97, true)
        GameTooltip:Show()
    end)
    categoryButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    controller.categoryButton = categoryButton

    local menu = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    menu:SetFrameStrata("FULLSCREEN_DIALOG")
    menu:SetFrameLevel(panel:GetFrameLevel() + 40)
    menu:SetPoint("TOPLEFT", categoryButton, "BOTTOMLEFT", 0, -2)
    SetBackdrop(menu, C.background, C.gold)
    menu:Hide()
    menu.buttons = {}

    local function SetCategory(id)
        controller.category = id
        categoryButton.label:SetText(id and CategoryName(id) or L("Alle Kategorien"))
        menu:Hide()
        controller.page = 1
        if RenderList then RenderList(controller) end
    end

    categoryButton:SetScript("OnClick", function()
        if menu:IsShown() then
            menu:Hide()
            return
        end

        local ordered, counts = CollectCategories(controller.source)
        local entries = { { id = nil, text = L("Alle Kategorien (") .. #(controller.source or {}) .. ")" } }
        for _, id in ipairs(ordered) do
            entries[#entries + 1] = { id = id, text = CategoryName(id) .. " (" .. counts[id] .. ")" }
        end

        for index, entry in ipairs(entries) do
            local button = menu.buttons[index]
            if not button then
                button = MakeButton(menu, "", 200, 24, C.gold)
                button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -6 - ((index - 1) * 26))
                button.label:SetWidth(186)
                button.label:SetWordWrap(false)
                menu.buttons[index] = button
            end
            button.label:SetText(entry.text)
            button:SetScript("OnClick", function() SetCategory(entry.id) end)
            button:Show()
        end
        for index = #entries + 1, #menu.buttons do
            menu.buttons[index]:Hide()
        end

        menu:SetSize(212, (#entries * 26) + 12)
        menu:Show()
    end)

    search:SetScript("OnTextChanged", function()
        controller.page = 1
        if RenderList then RenderList(controller) end
    end)
    previous:SetScript("OnClick", function()
        controller.page = math.max(1, controller.page - 1)
        if RenderList then RenderList(controller) end
    end)
    nextPage:SetScript("OnClick", function()
        local maxPage = math.max(1, math.ceil(#controller.filtered / ROWS_PER_PAGE))
        controller.page = math.min(maxPage, controller.page + 1)
        if RenderList then RenderList(controller) end
    end)

    return controller
end

RenderList = function(controller)
    local query = ""
    if controller.search and controller.search.GetText then
        query = tostring(controller.search:GetText() or ""):lower()
    end

    controller.filtered = {}
    for _, itemID in ipairs(controller.source or {}) do
        if MatchesSearch(itemID, query)
            and (not controller.category or ClassOf(itemID) == controller.category) then
            table.insert(controller.filtered, itemID)
        end
    end

    local maxPage = math.max(1, math.ceil(#controller.filtered / ROWS_PER_PAGE))
    controller.page = math.max(1, math.min(controller.page, maxPage))
    local first = ((controller.page - 1) * ROWS_PER_PAGE) + 1
    if controller.pageText then
        controller.pageText:SetText(L("Seite ") .. controller.page .. " / " .. maxPage)
    end

    for rowIndex, row in ipairs(controller.rows) do
        local itemID = controller.filtered[first + rowIndex - 1]
        if itemID then
            local name, idText, icon, link = BuildItemLabel(itemID)
            row.itemID = itemID
            row.itemLink = IsItemLink(link) and link or nil
            row.nameText:SetText(name)
            row.idText:SetText("#" .. idText)
            row.iconTexture:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
            row:Show()
        else
            row.itemID = nil
            row.itemLink = nil
            row:Hide()
        end
    end

    -- Buttons nur zeigen, wenn in diese Richtung geblaettert werden kann.
    controller.previous:SetShown(controller.page > 1)
    controller.nextPage:SetShown(controller.page < maxPage)
end

local function RefreshResultLists()
    if state.lists[1] then
        state.lists[1].source = state.scannedIDs or {}
        RenderList(state.lists[1])
    end
    if state.lists[2] then
        state.lists[2].source = state.newIDs or {}
        RenderList(state.lists[2])
    end
end

local function CreateWindow()
    if state.window then return state.window end
    if not UIParent or type(CreateFrame) ~= "function" then return nil end

    local panel = CreateFrame("Frame", "GTC_AHScanWindow", UIParent, "BackdropTemplate")
    panel:SetSize(900, 650)
    panel:SetPoint("CENTER", state.ahFrame or UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(100)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    SetBackdrop(panel, C.background, C.gold)

    local accentLine = panel:CreateTexture(nil, "ARTWORK")
    accentLine:SetColorTexture(unpack(C.cyan))
    accentLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -7)
    accentLine:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -7)
    accentLine:SetHeight(3)

    local title = MakeText(panel, "GameFontNormalLarge", "TOPLEFT", panel, "TOPLEFT", 22, -18, 650)
    title:SetText("GTC SCAN  /  ITEM CATALOGUE")
    title:SetTextColor(unpack(C.gold))

    local subtitle = MakeText(panel, "GameFontHighlightSmall", "TOPLEFT", panel, "TOPLEFT", 23, -43, 790)
    subtitle:SetText(L("AUKTIONSHAUS-DATEN  |  NUR GEGENSTÄNDE  |  KEINE PREISDATEN"))
    subtitle:SetTextColor(unpack(C.cyan))

    local closeButton = MakeButton(panel, L("SCHLIESSEN"), 124, 30, C.gold)
    closeButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -18)
    closeButton:SetScript("OnClick", function() panel:Hide() end)

    local lastCard = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    lastCard:SetSize(430, 80)
    lastCard:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -76)
    SetBackdrop(lastCard, C.card, C.cyan)
    local lastTitle = MakeText(lastCard, "GameFontNormal", "TOPLEFT", lastCard, "TOPLEFT", 12, -10, 398)
    lastTitle:SetText(L("LETZTER ERFOLGREICHER SCAN"))
    lastTitle:SetTextColor(unpack(C.cyan))
    state.lastScanText = MakeText(lastCard, "GameFontHighlightSmall", "TOPLEFT", lastCard, "TOPLEFT", 12, -31, 398)
    state.lastScanText:SetHeight(40)
    state.lastScanText:SetWordWrap(true)

    local progressCard = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    progressCard:SetSize(430, 92)
    progressCard:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -76)
    SetBackdrop(progressCard, C.card, C.gold)
    local progressTitle = MakeText(progressCard, "GameFontNormal", "TOPLEFT", progressCard, "TOPLEFT", 12, -10, 260)
    progressTitle:SetText("SCAN ENGINE")
    progressTitle:SetTextColor(unpack(C.gold))

    state.progressBar = CreateFrame("StatusBar", nil, progressCard)
    state.progressBar:SetSize(230, 15)
    state.progressBar:SetPoint("TOPLEFT", progressCard, "TOPLEFT", 12, -38)
    state.progressBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    state.progressBar:SetMinMaxValues(0, 1)
    state.progressBar:SetValue(0)
    state.progressBar:SetStatusBarColor(unpack(C.cyan))
    SetBackdrop(state.progressBar, C.row, C.cyan)

    state.progressText = MakeText(progressCard, "GameFontHighlightSmall", "LEFT", state.progressBar, "RIGHT", 8, 0, 40)
    state.progressText:SetText("0%")
    state.progressText:SetTextColor(unpack(C.cyan))

    local startButton = MakeButton(progressCard, L("SCAN STARTEN"), 122, 25, C.gold)
    startButton:SetPoint("BOTTOMRIGHT", progressCard, "BOTTOMRIGHT", -10, 7)
    startButton:SetScript("OnClick", function()
        if type(state.StartScan) == "function" then state.StartScan() end
    end)
    state.startButton = startButton

    local cancelButton = MakeButton(progressCard, L("ABBRECHEN"), 112, 25, C.red)
    cancelButton:SetPoint("RIGHT", startButton, "LEFT", -8, 0)
    cancelButton:SetScript("OnClick", function()
        if type(state.CancelScan) == "function" then state.CancelScan() end
    end)
    cancelButton:Disable()
    state.cancelButton = cancelButton

    state.statusText = MakeText(panel, "GameFontHighlightSmall", "TOPLEFT", panel, "TOPLEFT", 22, -180, 850)
    state.statusText:SetText(L(state.status))
    state.statusText:SetTextColor(unpack(C.muted))

    CreateListPanel(panel, L("GESCANNTE ITEMS"), L("Einzigartige Gegenstände aus diesem AH-Scan"), "TOPLEFT", 18)
    CreateListPanel(panel, L("NEU IM KATALOG"), L("Gegenstände, die vorher noch nicht vorhanden waren"), "TOPRIGHT", -18)
    for _, list in ipairs(state.lists) do
        list.panel:ClearAllPoints()
        if list == state.lists[1] then
            list.panel:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -190)
        else
            list.panel:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -190)
        end
    end

    panel:SetScript("OnShow", function()
        RefreshHeader()
        RefreshResultLists()
    end)
    panel:SetScript("OnHide", function()
        GameTooltip:Hide()
    end)
    panel:SetScript("OnUpdate", function(_, elapsed)
        state.uiElapsed = state.uiElapsed + elapsed
        if state.uiElapsed >= 1.5 then
            state.uiElapsed = 0
            RefreshHeader()
        end
    end)

    state.window = panel
    RefreshHeader()
    RefreshResultLists()
    return panel
end

local function SetProgress(processed, total)
    state.processed = processed or 0
    state.total = total or 0
    if total and total > 0 then
        local fraction = math.max(0, math.min(1, processed / total))
        if state.commitMode then
            state.progress = 0.85 + (fraction * 0.15)
        else
            state.progress = fraction * 0.85
        end
    else
        state.progress = state.commitMode and 0.85 or 0
    end
    RefreshHeader()
end

local function FinishScan(success, message)
    state.awaitingReplication = false
    state.running = false
    state.requestToken = state.requestToken + 1

    if state.startButton then state.startButton:Enable() end
    if state.cancelButton then state.cancelButton:Disable() end

    if success then
        local now = time()
        local db = GetDB()
        if not db then
            SetStatus(L("Scan-Ergebnis konnte nicht gespeichert werden: Datenbereich fehlt."), true)
            RefreshHeader()
            return
        end

        db.scan.ahLatestScan = {
            at = now,
            character = CurrentPlayerName(),
            source = "ah",
        }

        state.scannedIDs = state.pendingScannedIDs or {}
        state.newIDs = state.pendingNewIDs or {}
        state.pendingScannedIDs = {}
        state.pendingNewIDs = {}
        state.pendingItemData = {}
        state.seenThisScan = {}
        state.pendingMetadata = state.pendingMetadata or {}
        state.commitMode = false
        state.progress = 1
        if (tonumber(state.commitErrors) or 0) > 0 then
            SetStatus(L("Scan abgeschlossen; einzelne Item-Datensätze konnten nicht ergänzt werden."), true)
        else
            SetStatus(L("Scan erfolgreich abgeschlossen. Der Item-Katalog wurde ergänzt."), false)
        end
        state.commitErrors = 0
        RefreshResultLists()

        if type(GTC.ScheduleGuildSync) == "function" then
            pcall(GTC.ScheduleGuildSync, GTC)
        end
        if type(GTC.Print) == "function" then
            pcall(GTC.Print, GTC, L("GTC-AH-Scan abgeschlossen. Mitglieder können den Katalog über „Von Gilde laden“ abrufen."))
        end
    else
        SetStatus(message or L("Scan abgebrochen. Der letzte erfolgreiche Scan bleibt erhalten."), true)
        state.pendingScannedIDs = {}
        state.pendingNewIDs = {}
        state.pendingItemData = {}
        state.seenThisScan = {}
        state.commitMode = false
        state.commitIndex = 1
        state.commitErrors = 0
        if state.progressBar then
            state.progress = 0
        end
    end

    RefreshHeader()
end

local function ProcessOneAuction(index)
    local api = C_AuctionHouse
    if not api or type(api.GetReplicateItemInfo) ~= "function" then
        return true
    end

    local ok, itemName, itemIcon, ignoredQuantity, itemQuality, ignoredUsable,
        ignoredLevel, ignoredLevelType, ignoredMinBid, ignoredMinIncrement,
        ignoredBuyout, ignoredBidAmount, ignoredHighBidder, ignoredBidder,
        ignoredOwner, ignoredOwnerRealm, ignoredSaleStatus, itemID =
        pcall(api.GetReplicateItemInfo, index)

    if not ok then
        return true
    end

    itemID = tonumber(itemID)
    local itemLink
    if type(api.GetReplicateItemLink) == "function" then
        local linkOK, linkValue = pcall(api.GetReplicateItemLink, index)
        if linkOK and IsItemLink(linkValue) then
            itemLink = linkValue
        end
    end
    if not itemID and itemLink then
        itemID = tonumber(itemLink:match("|[Hh]item:(%d+)"))
    end
    if not itemID or itemID < 1 then
        return true
    end

    local key = tostring(itemID)
    if state.seenThisScan[key] then
        return true
    end
    state.seenThisScan[key] = true
    table.insert(state.pendingScannedIDs, key)
    -- Stage only item metadata in memory. Nothing is added to SavedVariables
    -- until the complete replicated auction list has been processed.
    state.pendingItemData[key] = {
        itemID = itemID,
        itemName = type(itemName) == "string" and itemName or nil,
        itemIcon = ((type(itemIcon) == "number" or type(itemIcon) == "string") and itemIcon) or nil,
        itemQuality = type(itemQuality) == "number" and itemQuality or nil,
        itemLink = IsItemLink(itemLink) and itemLink or nil,
    }
    return true
end

local CommitCatalogBatch

local function ProcessBatch(token)
    if token ~= state.requestToken or not state.running then return end

    local api = C_AuctionHouse
    if not api or type(api.GetNumReplicateItems) ~= "function" then
        FinishScan(false, L("Die Replicate-API ist nicht verfügbar. Der letzte gültige Katalog bleibt erhalten."))
        return
    end

    local lastIndex = math.min(state.total - 1, state.processed + SCAN_BATCH_SIZE - 1)
    while state.processed <= lastIndex do
        local index = state.processed
        local ok, err = pcall(ProcessOneAuction, index)
        if not ok then
            FinishScan(false, L("Fehler bei der Item-Verarbeitung. Der letzte erfolgreiche Scan bleibt gültig."))
            if type(GTC.Print) == "function" then pcall(GTC.Print, GTC, tostring(err)) end
            return
        end
        state.processed = state.processed + 1
    end

    SetProgress(state.processed, state.total)
    if state.processed >= state.total then
        state.commitMode = true
        if state.cancelButton then state.cancelButton:Disable() end
        state.commitIndex = 1
        state.processed = 0
        state.total = #state.pendingScannedIDs
        state.commitErrors = 0
        SetStatus(L("Scan erfasst. Übernehme reine Item-Daten in den GTC-Katalog ..."), false)
        CommitCatalogBatch(token)
        return
    end

    C_Timer.After(SCAN_BATCH_DELAY, function() ProcessBatch(token) end)
end

CommitCatalogBatch = function(token)
    if token ~= state.requestToken or not state.running then return end

    local count = #state.pendingScannedIDs
    if count == 0 then
        FinishScan(true)
        return
    end

    local lastIndex = math.min(count, state.commitIndex + SCAN_BATCH_SIZE - 1)
    while state.commitIndex <= lastIndex do
        local key = state.pendingScannedIDs[state.commitIndex]
        local record = state.pendingItemData[key]
        if type(record) == "table" then
            local ok, remembered, wasNew = pcall(
                RememberCatalogItem,
                record.itemID,
                record.itemName,
                record.itemIcon,
                record.itemQuality,
                record.itemLink
            )
            if ok and remembered and wasNew then
                table.insert(state.pendingNewIDs, key)
            elseif not ok or not remembered then
                state.commitErrors = (state.commitErrors or 0) + 1
            end
        else
            state.commitErrors = (state.commitErrors or 0) + 1
        end
        state.commitIndex = state.commitIndex + 1
    end

    SetProgress(state.commitIndex - 1, count)
    if state.commitIndex > count then
        FinishScan(true)
        return
    end
    C_Timer.After(SCAN_BATCH_DELAY, function() CommitCatalogBatch(token) end)
end

local function BeginProcessing()
    if not state.awaitingReplication then return end
    state.awaitingReplication = false

    local api = C_AuctionHouse
    if not api or type(api.GetNumReplicateItems) ~= "function" then
        FinishScan(false, L("Die Auktionshaus-Scan-API ist nicht verfügbar."))
        return
    end

    local ok, total = pcall(api.GetNumReplicateItems)
    if not ok or type(total) ~= "number" or total < 0 then
        FinishScan(false, L("Das Auktionshaus hat keine gültige Item-Liste geliefert."))
        return
    end

    state.total = math.floor(total)
    state.processed = 0
    state.seenThisScan = {}
    state.pendingScannedIDs = {}
    state.pendingNewIDs = {}
    state.pendingItemData = {}
    state.commitMode = false
    state.commitIndex = 1
    state.commitErrors = 0
    state.progress = 0
    state.running = true
    SetStatus(L("Verarbeite gefundene Gegenstände ..."), false)

    if state.total == 0 then
        FinishScan(true)
        return
    end

    local token = state.requestToken
    ProcessBatch(token)
end

local function CancelScan()
    if not state.running and not state.awaitingReplication then
        SetStatus(L("Es läuft derzeit kein Scan."), false)
        return
    end
    if state.commitMode then
        SetStatus(L("Die Katalogübernahme läuft bereits und wird sicher abgeschlossen."), false)
        return
    end

    state.awaitingReplication = false
    state.running = false
    state.requestToken = state.requestToken + 1
    state.pendingScannedIDs = {}
    state.pendingNewIDs = {}
    state.pendingItemData = {}
    state.seenThisScan = {}
    state.pendingMetadata = state.pendingMetadata or {}
    state.progress = 0
    state.commitMode = false
    if state.startButton then state.startButton:Enable() end
    if state.cancelButton then state.cancelButton:Disable() end
    SetStatus(L("Scan abgebrochen. Katalog und letzter erfolgreicher Scan bleiben erhalten."), false)
    RefreshHeader()
end
state.CancelScan = CancelScan

local function ReplicateListSize()
    local api = C_AuctionHouse
    if not api or type(api.GetNumReplicateItems) ~= "function" then return 0 end
    local ok, count = pcall(api.GetNumReplicateItems)
    if ok and type(count) == "number" and count > 0 then return math.floor(count) end
    return 0
end

local function StartScan()
    if state.running or state.awaitingReplication then
        SetStatus(L("Ein Scan läuft bereits."), false)
        return
    end

    local db = GetDB()
    if not db then
        SetStatus(L("Der GTC-Datenbereich ist noch nicht bereit."), true)
        return
    end

    local api = C_AuctionHouse
    if not C_Timer or type(C_Timer.After) ~= "function" then
        SetStatus(L("Die Timer-API dieser Spielversion ist nicht verfügbar; kein Scan gestartet."), true)
        return
    end
    if not api or type(api.ReplicateItems) ~= "function"
        or type(api.GetNumReplicateItems) ~= "function"
        or type(api.GetReplicateItemInfo) ~= "function" then
        SetStatus(L("Diese Spielversion stellt die benötigte AH-Scan-API nicht bereit."), true)
        return
    end

    -- Hat ein anderes AH-Addon die Liste bereits geladen, wird sie uebernommen. Das
    -- vermeidet eine eigene Anfrage und damit die serverseitige Drosselung.
    local seenAt = tonumber(state.replicateSeenAt) or 0
    if seenAt > 0 and (time() - seenAt) < 1800 and ReplicateListSize() > 0 then
        state.replicateSeenAt = nil
        state.requestToken = state.requestToken + 1
        state.awaitingReplication = true
        state.running = false
        state.progress = 0
        state.processed = 0
        state.total = 0
        SetStatus(L("Übernehme die bereits geladene AH-Liste eines anderen Addons ..."), false)
        if state.startButton then state.startButton:Disable() end
        if state.cancelButton then state.cancelButton:Enable() end
        RefreshHeader()
        BeginProcessing()
        return
    end

    local now = time()
    local savedRequestAt = tonumber(db.scan.ahLastRequestAt) or 0
    local lastRequestAt = math.max(state.lastRequestAt or 0, savedRequestAt)
    if lastRequestAt > 0 and (now - lastRequestAt) < API_COOLDOWN then
        local remaining = API_COOLDOWN - (now - lastRequestAt)
        local minutes = math.ceil(remaining / 60)
        SetStatus(L("Die AH-API ist noch gedrosselt. Bitte ungefähr ") .. tostring(minutes) .. L(" Minuten warten."), true)
        return
    end

    state.requestToken = state.requestToken + 1
    local token = state.requestToken
    state.awaitingReplication = true
    state.running = false
    state.progress = 0
    state.processed = 0
    state.total = 0
    state.lastRequestAt = now
    db.scan.ahLastRequestAt = now
    SetStatus(L("Warte auf die Item-Liste des Auktionshauses ..."), false)
    if state.startButton then state.startButton:Disable() end
    if state.cancelButton then state.cancelButton:Enable() end
    RefreshHeader()

    local callOK = pcall(api.ReplicateItems)
    if not callOK then
        FinishScan(false, L("Die AH-Anfrage wurde vom Client abgelehnt. Warte die API-Sperre ab."))
        return
    end

    C_Timer.After(60, function()
        if state.requestToken == token and state.awaitingReplication then
            if ReplicateListSize() > 0 then
                SetStatus(L("Keine neue Antwort vom Auktionshaus - verwende die zuletzt geladene Liste."), false)
                BeginProcessing()
                return
            end
            FinishScan(false, L("Keine Antwort vom Auktionshaus erhalten. Möglich sind API-Drosselung oder fehlende Serverantwort."))
        end
    end)
end
state.StartScan = StartScan

-- Position der Scan-Kachel (kontoweit, nicht synchronisiert): Offset relativ zur
-- oberen linken Ecke des Auktionshaus-Fensters. nil = Standardplatz am rechten Rand.
local function GetTabPosition()
    local root = _G.GuildTradeCenterDB
    local pos = type(root) == "table" and root.ahTabPos or nil
    if type(pos) == "table" and tonumber(pos.x) and tonumber(pos.y) then
        return tonumber(pos.x), tonumber(pos.y)
    end
    return nil
end

local function SaveTabPosition(x, y)
    local root = _G.GuildTradeCenterDB
    if type(root) ~= "table" then return end
    if x == nil then
        root.ahTabPos = nil
    else
        root.ahTabPos = { x = x, y = y }
    end
end

local function ApplyTabPosition(tab, frame)
    tab:ClearAllPoints()
    local x, y = GetTabPosition()
    if x then
        tab:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
    else
        -- Standard: senkrechte Kachel direkt am rechten Aussenrand, unterhalb der Kopfzeile.
        tab:SetPoint("TOPLEFT", frame, "TOPRIGHT", 0, -120)
    end
end

local function AttachTab()
    local frame = _G.AuctionHouseFrame or _G.AuctionFrame
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    if state.tab and state.ahFrame == frame then
        return true
    end
    if state.tab and state.ahFrame ~= frame then
        state.tab:Hide()
        state.tab = nil
    end
    if state.window and state.ahFrame ~= frame then
        state.window:Hide()
        state.window:ClearAllPoints()
    end

    state.ahFrame = frame
    local tab = CreateFrame("Button", "GTC_AHScanTab", frame, "BackdropTemplate")
    tab:SetSize(44, 78)
    tab:SetFrameStrata(frame:GetFrameStrata() or "HIGH")
    tab:SetFrameLevel((frame:GetFrameLevel() or 1) + 12)
    SetBackdrop(tab, C.panel, C.gold)

    local label = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", tab, "CENTER", 0, 0)
    label:SetText("GTC\nSCAN")
    label:SetTextColor(unpack(C.gold))
    tab.label = label

    tab:SetScript("OnEnter", function(self)
        SetBackdrop(self, C.card, C.cyan)
        self.label:SetTextColor(unpack(C.cyan))
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("GTC Scan", 1, 0.82, 0.35)
        GameTooltip:AddLine(L("AH-Itemdaten in den GTC-Katalog übernehmen"), 0.8, 0.9, 0.95, true)
        GameTooltip:AddLine(L("Es werden keine Auktionspreise gespeichert."), 0.25, 0.83, 0.82, true)
        GameTooltip:AddLine(L("Ziehen: Kachel verschieben - Rechtsklick: Position zurücksetzen"), 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", function(self)
        SetBackdrop(self, C.panel, C.gold)
        self.label:SetTextColor(unpack(C.gold))
        GameTooltip:Hide()
    end)
    tab:SetMovable(true)
    tab:SetClampedToScreen(true)
    tab:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    tab:RegisterForDrag("LeftButton")
    tab:SetScript("OnDragStart", function(self)
        self.gtcDragging = true
        GameTooltip:Hide()
        self:StartMoving()
    end)
    tab:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local fLeft, fTop = frame:GetLeft(), frame:GetTop()
        local tLeft, tTop = self:GetLeft(), self:GetTop()
        if fLeft and fTop and tLeft and tTop then
            -- Kind und Eltern teilen dieselbe effektive Skalierung, die Differenz passt direkt.
            SaveTabPosition(tLeft - fLeft, tTop - fTop)
        end
        ApplyTabPosition(self, frame)
        -- Das Klick-Ereignis nach dem Loslassen soll das Fenster nicht umschalten.
        C_Timer.After(0, function() self.gtcDragging = nil end)
    end)
    tab:SetScript("OnClick", function(self, button)
        if self.gtcDragging then return end
        if button == "RightButton" then
            SaveTabPosition(nil)
            ApplyTabPosition(self, frame)
            return
        end
        local panel = CreateWindow()
        if panel then
            if panel:IsShown() then panel:Hide() else panel:Show() end
            RefreshHeader()
            RefreshResultLists()
        end
    end)

    ApplyTabPosition(tab, frame)

    state.tab = tab
    local panel = CreateWindow()
    if panel then panel:Hide() end

    if type(frame.HookScript) == "function" then
        frame:HookScript("OnHide", function()
            if state.window then state.window:Hide() end
        end)
    end
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
eventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
eventFrame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE")
eventFrame:RegisterEvent("GET_ITEM_INFO_RECEIVED")
eventFrame:RegisterEvent("ITEM_DATA_LOAD_RESULT")

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
        local db = GetDB()
        if db then
            local lastRequestAt = tonumber(db.scan.ahLastRequestAt) or 0
            if lastRequestAt > state.lastRequestAt then state.lastRequestAt = lastRequestAt end
        end
        if event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
            AttachTab()
        end
        return
    end

    if event == "AUCTION_HOUSE_SHOW" then
        -- Falls das AH-Fenster erst nach diesem Handler sichtbar wird: im naechsten Frame
        -- erneut versuchen.
        if not AttachTab() and C_Timer and type(C_Timer.After) == "function" then
            C_Timer.After(0, AttachTab)
        end
        return
    end

    if event == "AUCTION_HOUSE_CLOSED" then
        if state.window then state.window:Hide() end
        return
    end

    if event == "REPLICATE_ITEM_LIST_UPDATE" then
        if state.awaitingReplication then
            BeginProcessing()
        else
            -- Ein anderes Addon hat die Liste angefordert: merken, damit wir sie nutzen koennen.
            state.replicateSeenAt = time()
        end
        return
    end

    if event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        local itemID = tonumber((...))
        if not itemID then return end
        local key = tostring(itemID)
        if not state.pendingMetadata[key] then return end
        local db = GetDB()
        local entry = db and db.items[key] or nil
        if type(entry) == "table" then
            TouchMetadataForSync(itemID)
            entry = db.items[key]
            if type(entry) == "table" and entry.name and IsItemLink(entry.itemLink)
                and entry.icon and tonumber(entry.quality) then
                state.pendingMetadata[key] = nil
            end
        end
        -- Gebuendelt und nur bei offenem Fenster: Nach einem grossen Scan treffen tausende
        -- Item-Ereignisse ein; vorher filterte jedes beide Listen komplett neu.
        if state.window and state.window:IsShown() and not state.listRefreshPending then
            state.listRefreshPending = true
            C_Timer.After(0.5, function()
                state.listRefreshPending = false
                if state.window and state.window:IsShown() then
                    RefreshResultLists()
                end
            end)
        end
    end
end)

-- If the module loaded after the AH frame already existed, try once at load time.
AttachTab()