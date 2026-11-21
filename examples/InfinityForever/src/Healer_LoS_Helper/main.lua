local L = Healer_LoS_Helper_Locale or {}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("UI_ERROR_MESSAGE")

local addonName = "Healer_LoS_Helper"
local lastClickTime = 0
local clickCount = 0
local lastError
local symbolGeneration = 0

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function ReadableUnitResult(func, ...)
    local value = func(...)
    if IsSecret(value) then return nil end
    return value
end

local defaults = {
    requiredClicks = 3,
    clickThreshold = 0.5,
    displayDuration = 7,
    showOutOfRange = true,
    notifyTargetLoS = false,
    notifyTargetRange = false,
    spamInterval = 5,
    messageLanguage = "enUS",
    hpThreshold = 80,
    lastMsgTimes = {},
}

local notificationMessages = {
    enUS = {
        los = "I can't heal you - line of sight! (%d%% HP)",
        range = "I can't heal you - out of range! (%d%% HP)",
    },
    deDE = {
        los = "Ich kann dich nicht heilen - keine Sichtlinie! (%d%% HP)",
        range = "Ich kann dich nicht heilen - ausser Reichweite! (%d%% HP)",
    },
}

local symbolFrame = CreateFrame("Frame", nil, UIParent)
symbolFrame:SetSize(40, 40)
symbolFrame:Hide()
symbolFrame.text = symbolFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
symbolFrame.text:SetPoint("CENTER")
symbolFrame.text:SetTextColor(1, 0, 0)

local function ApplyDefaults(db, template)
    for key, value in pairs(template) do
        if type(value) == "table" then
            if type(db[key]) ~= "table" then
                db[key] = {}
            end
            ApplyDefaults(db[key], value)
        elseif db[key] == nil then
            db[key] = value
        end
    end
end

local function ShowSymbolAtCursor(symbol)
    local x, y = GetCursorPosition()
    local s = UIParent:GetEffectiveScale()

    symbolFrame:ClearAllPoints()
    symbolFrame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
    symbolFrame.text:SetText(symbol)
    symbolFrame:Show()
    symbolGeneration = symbolGeneration + 1
    local generation = symbolGeneration
    C_Timer.After(Healer_LoS_HelperDB.displayDuration, function()
        if generation == symbolGeneration then symbolFrame:Hide() end
    end)
end

local function IsGroupedUnit(unit)
    if not unit or not ReadableUnitResult(UnitExists, unit) or not ReadableUnitResult(UnitIsPlayer, unit) then
        return false
    end

    local sameUnit = UnitIsUnit(unit, "player")
    if IsSecret(sameUnit) then return false end
    if sameUnit then
        return false
    end

    return ReadableUnitResult(UnitInParty, unit) or ReadableUnitResult(UnitInRaid, unit)
end

local function SendNotification(unitName, message)
    local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
    if not send then return false end
    -- New clients can restrict automatic messages. Never bypass restrictions.
    return pcall(send, message, "WHISPER", nil, unitName)
end

local function GetNotificationMessage(messageKey, percent)
    local language = Healer_LoS_HelperDB.messageLanguage or "enUS"
    local messages = notificationMessages[language] or notificationMessages.enUS
    return format(messages[messageKey] or notificationMessages.enUS[messageKey], percent)
end

local LOS_MSG = ERR_LINE_OF_SIGHT or SPELL_FAILED_LINE_OF_SIGHT or "Target not in line of sight"
local RANGE_MSG = ERR_OUT_OF_RANGE or SPELL_FAILED_OUT_OF_RANGE or "Out of range"

f:SetScript("OnEvent", function(_, event, arg1, msg)
    if event == "ADDON_LOADED" and arg1 == addonName then
        Healer_LoS_HelperDB = Healer_LoS_HelperDB or {}
        ApplyDefaults(Healer_LoS_HelperDB, defaults)
        -- Apply the new opt-in notification default once on upgrade. Later
        -- choices made in the options remain intact across reloads.
        if not Healer_LoS_HelperDB.quietDefaultsApplied then
            if Healer_LoS_HelperDB.clickThreshold == 0.2 then
                Healer_LoS_HelperDB.clickThreshold = defaults.clickThreshold
            end
            Healer_LoS_HelperDB.notifyTargetLoS = false
            Healer_LoS_HelperDB.notifyTargetRange = false
            Healer_LoS_HelperDB.quietDefaultsApplied = true
        end
        -- GetTime is session-relative; persisted timestamps cannot be reused.
        Healer_LoS_HelperDB.lastMsgTimes = {}
        return
    end

    if not Healer_LoS_HelperDB then
        return
    end

    if event == "UI_ERROR_MESSAGE" and IsSecret(msg) then return end
    if event == "UI_ERROR_MESSAGE" and (msg == LOS_MSG or (msg == RANGE_MSG and Healer_LoS_HelperDB.showOutOfRange)) then
        local now = GetTime()
        if lastError ~= msg or now - lastClickTime > Healer_LoS_HelperDB.clickThreshold then
            clickCount = 1
        else
            clickCount = clickCount + 1
        end
        lastClickTime = now
        lastError = msg

        if clickCount >= Healer_LoS_HelperDB.requiredClicks then
            local symbol = (msg == LOS_MSG) and "X" or "0"
            ShowSymbolAtCursor(symbol)
            clickCount = 0

            local unit = ReadableUnitResult(UnitExists, "mouseover") and "mouseover" or (ReadableUnitResult(UnitExists, "target") and "target")
            if IsGroupedUnit(unit) then
                local name, realm = UnitName(unit)
                local maxHp = UnitHealthMax(unit)
                local currentHp = UnitHealth(unit)
                if IsSecret(name) or IsSecret(realm) or IsSecret(maxHp) or IsSecret(currentHp) then return end
                if not name or type(maxHp) ~= "number" or maxHp <= 0 or type(currentHp) ~= "number" then
                    return
                end
                if realm and realm ~= "" then name = name .. "-" .. realm end

                local hp = currentHp / maxHp * 100
                local percent = math.floor(hp + 0.5)
                local threshold = Healer_LoS_HelperDB.hpThreshold or 100

                Healer_LoS_HelperDB.lastMsgTimes = Healer_LoS_HelperDB.lastMsgTimes or {}
                local lastMsgTime = Healer_LoS_HelperDB.lastMsgTimes[name]
                local tooSoon = lastMsgTime and now - lastMsgTime < (Healer_LoS_HelperDB.spamInterval or 5)

                if percent <= threshold and not tooSoon then
                    local sent
                    if msg == LOS_MSG and Healer_LoS_HelperDB.notifyTargetLoS then
                        sent = SendNotification(name, GetNotificationMessage("los", percent))
                    elseif msg == RANGE_MSG and Healer_LoS_HelperDB.notifyTargetRange then
                        sent = SendNotification(name, GetNotificationMessage("range", percent))
                    end
                    if sent then Healer_LoS_HelperDB.lastMsgTimes[name] = now end
                end
            end
        end
    end
end)

SLASH_LOSXM1 = "/hlosh"
SlashCmdList["LOSXM"] = function()
    if not Healer_LoS_HelperDB then
        print(L["DB_NOT_READY"] or "Database not loaded yet - please try again in a moment.")
        return
    end

    if not Healer_LoS_Helper_Options then
        print(L["OPTIONS_NOT_READY"] or "Options not loaded.")
        return
    end

    if Healer_LoS_Helper_Options.Open then
        Healer_LoS_Helper_Options:Open()
        return
    end

    if not Healer_LoS_Helper_Options.slidersInitialized then
        Healer_LoS_Helper_Options:InitSliders()
    end

    if Healer_LoS_Helper_Options:IsShown() then
        Healer_LoS_Helper_Options:Hide()
    else
        Healer_LoS_Helper_Options:Show()
    end
end
