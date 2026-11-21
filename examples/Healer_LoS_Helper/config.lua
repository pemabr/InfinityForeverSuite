-- Anniversary/Era-friendly options window.
-- Registers in Blizzard's addon options when available and keeps a standalone fallback.

local L = Healer_LoS_Helper_Locale or {}

local function CreateSliderAbsolute(parent, name, minVal, maxVal, step, defaultVal, y, labelText, onValueChanged, isDecimal)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetValue(defaultVal)
    slider:SetWidth(280)
    slider:SetHeight(24)
    slider:SetOrientation("HORIZONTAL")
    slider:EnableMouse(true)
    slider:SetObeyStepOnDrag(true)

    -- Hide template-provided labels because they can overlap in Classic clients.
    local tText = _G[name .. "Text"]
    local tLow = _G[name .. "Low"]
    local tHigh = _G[name .. "High"]
    if tText then tText:Hide() end
    if tLow then tLow:Hide() end
    if tHigh then tHigh:Hide() end

    local thumb = "Interface\\Buttons\\UI-SliderBar-Button-Horizontal"
    slider:SetThumbTexture(thumb)
    local thumbTexture = slider:GetThumbTexture()
    if thumbTexture then
        thumbTexture:SetSize(24, 32)
        thumbTexture:SetDrawLayer("OVERLAY", 1)
    end

    slider.TrackBG = slider:CreateTexture(nil, "BACKGROUND")
    slider.TrackBG:SetTexture("Interface\\Buttons\\WHITE8x8")
    slider.TrackBG:SetPoint("LEFT", slider, "LEFT", 8, 0)
    slider.TrackBG:SetPoint("RIGHT", slider, "RIGHT", -8, 0)
    slider.TrackBG:SetHeight(8)
    slider.TrackBG:SetVertexColor(0.08, 0.08, 0.08, 0.95)

    slider.TrackBorder = slider:CreateTexture(nil, "BORDER")
    slider.TrackBorder:SetTexture("Interface\\Buttons\\WHITE8x8")
    slider.TrackBorder:SetPoint("LEFT", slider.TrackBG, "LEFT", -1, 0)
    slider.TrackBorder:SetPoint("RIGHT", slider.TrackBG, "RIGHT", 1, 0)
    slider.TrackBorder:SetPoint("TOP", slider.TrackBG, "TOP", 0, 1)
    slider.TrackBorder:SetPoint("BOTTOM", slider.TrackBG, "BOTTOM", 0, -1)
    slider.TrackBorder:SetVertexColor(0.55, 0.42, 0.12, 0.9)

    slider.TrackFill = slider:CreateTexture(nil, "ARTWORK")
    slider.TrackFill:SetTexture("Interface\\Buttons\\WHITE8x8")
    slider.TrackFill:SetPoint("LEFT", slider.TrackBG, "LEFT", 1, 0)
    slider.TrackFill:SetHeight(6)
    slider.TrackFill:SetVertexColor(0.95, 0.78, 0.12, 0.95)

    slider.Text = slider:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    slider.Text:SetPoint("BOTTOM", slider, "TOP", 0, 6)
    slider.Text:SetJustifyH("CENTER")
    slider.Text:SetTextColor(1, 0.82, 0)

    slider.Low = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.Low:SetPoint("TOPLEFT", slider.TrackBG, "BOTTOMLEFT", -2, -6)
    slider.Low:SetJustifyH("LEFT")
    slider.Low:SetTextColor(0.95, 0.95, 0.95)

    slider.High = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    slider.High:SetPoint("TOPRIGHT", slider.TrackBG, "BOTTOMRIGHT", 2, -6)
    slider.High:SetJustifyH("RIGHT")
    slider.High:SetTextColor(0.95, 0.95, 0.95)

    slider.Low:SetText(tostring(minVal))
    slider.High:SetText(tostring(maxVal))

    local function fmt(v)
        if isDecimal then
            return string.format("%.2f", v)
        end
        return tostring(math.floor(v + 0.5))
    end

    slider.Text:SetText(labelText .. ": " .. fmt(defaultVal))
    slider:SetPoint("TOP", parent, "TOP", 0, y)

    local function UpdateSliderVisual(self)
        local minSlider, maxSlider = self:GetMinMaxValues()
        local value = self:GetValue()
        local ratio = 0
        if maxSlider > minSlider then
            ratio = (value - minSlider) / (maxSlider - minSlider)
        end

        local width = self.TrackBG:GetWidth() - 2
        local fillWidth = math.max(8, width * ratio)
        self.TrackFill:SetWidth(fillWidth)
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if onValueChanged then
            onValueChanged(self, value)
        end
        slider.Text:SetText(labelText .. ": " .. fmt(self:GetValue()))
        UpdateSliderVisual(self)
    end)

    UpdateSliderVisual(slider)
    slider.UpdateSliderVisual = UpdateSliderVisual

    return slider
end

Healer_LoS_Helper_Options = CreateFrame("Frame", "Healer_LoS_Helper_Options", UIParent, "BackdropTemplate")
local opt = Healer_LoS_Helper_Options

opt:SetSize(420, 620)
opt:SetPoint("CENTER")
opt:SetFrameStrata("DIALOG")
opt:SetFrameLevel(1000)
opt:SetClampedToScreen(true)
opt:EnableMouse(true)
opt:SetMovable(true)
opt:RegisterForDrag("LeftButton")
opt:SetScript("OnDragStart", opt.StartMoving)
opt:SetScript("OnDragStop", opt.StopMovingOrSizing)

opt:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
})
opt:SetBackdropColor(0, 0, 0, 1)

opt.title = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
opt.title:SetPoint("TOP", 0, -14)
opt.title:SetText(L["OPTIONS_TITLE"] or "Healer LoS Helper Options")

opt.close = CreateFrame("Button", nil, opt, "UIPanelCloseButton")
opt.close:SetPoint("TOPRIGHT", -6, -6)

opt:Hide()
opt.name = "Healer LoS Helper"
opt:SetScript("OnShow", function(self)
    if Healer_LoS_HelperDB and not self.slidersInitialized then
        self:InitSliders()
    end
end)

local function CreateCheckbox(parent, name, label, x, y)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    cb:SetSize(20, 20)

    local textRegion = _G[name .. "Text"]
    if textRegion then
        textRegion:SetText(label)
        textRegion:ClearAllPoints()
        textRegion:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        cb.text = textRegion
    else
        cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        cb.text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
        cb.text:SetText(label)
    end

    local textWidth = cb.text:GetStringWidth() or 0
    local rowWidth = cb:GetWidth() + 6 + textWidth
    local centeredX = math.max(20, (parent:GetWidth() - rowWidth) / 2)
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", centeredX, y)

    return cb
end

local messageLanguages = {
    { value = "enUS", text = "English" },
    { value = "deDE", text = "Deutsch" },
}

local function GetMessageLanguageText(value)
    for _, language in ipairs(messageLanguages) do
        if language.value == value then
            return language.text
        end
    end

    return "English"
end

local function CreateMessageLanguageDropdown(parent, x, y)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", parent, "TOP", 0, y)
    label:SetText(L["OPTIONS_MESSAGE_LANGUAGE"] or "Whisper language")

    local dropdown = CreateFrame("Frame", "HLOSH_MessageLanguageDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOP", label, "BOTTOM", -8, -8)

    UIDropDownMenu_SetWidth(dropdown, 160)
    UIDropDownMenu_SetText(dropdown, GetMessageLanguageText(Healer_LoS_HelperDB.messageLanguage or "enUS"))

    UIDropDownMenu_Initialize(dropdown, function(self, level)
        local info = UIDropDownMenu_CreateInfo()
        for _, language in ipairs(messageLanguages) do
            info.text = language.text
            info.value = language.value
            info.checked = Healer_LoS_HelperDB.messageLanguage == language.value
            info.func = function(button)
                Healer_LoS_HelperDB.messageLanguage = button.value
                UIDropDownMenu_SetText(dropdown, GetMessageLanguageText(button.value))
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    return dropdown
end

function opt:InitSliders()
    if self.slidersInitialized then return end

    self.clicksSlider = CreateSliderAbsolute(
        self,
        "HLOSH_ClickSlider",
        1,
        5,
        1,
        Healer_LoS_HelperDB.requiredClicks or 3,
        -60,
        L["OPTIONS_REQUIRED_CLICKS"] or "Required errors",
        function(self, value)
            local v = math.floor(value + 0.5)
            Healer_LoS_HelperDB.requiredClicks = v
            if self:GetValue() ~= v then
                self:SetValue(v)
            end
        end,
        false
    )

    self.thresholdSlider = CreateSliderAbsolute(
        self,
        "HLOSH_TimeSlider",
        0.1,
        3,
        0.1,
        Healer_LoS_HelperDB.clickThreshold or 0.5,
        -130,
        L["OPTIONS_CLICK_THRESHOLD"] or "Time window (seconds)",
        function(self, value)
            local v = math.floor((value + 0.05) * 10) / 10
            Healer_LoS_HelperDB.clickThreshold = v
            if self:GetValue() ~= v then
                self:SetValue(v)
            end
        end,
        true
    )

    self.thresholdSlider.Text:SetText((L["OPTIONS_CLICK_THRESHOLD"] or "Time window (seconds)") .. ": " .. string.format("%.1f", Healer_LoS_HelperDB.clickThreshold or 0.5))
    self.thresholdSlider:SetScript("OnValueChanged", function(sl, value)
        local v = math.floor((value + 0.05) * 10) / 10
        Healer_LoS_HelperDB.clickThreshold = v
        if sl:GetValue() ~= v then
            sl:SetValue(v)
        end
        sl.Text:SetText((L["OPTIONS_CLICK_THRESHOLD"] or "Time window (seconds)") .. ": " .. string.format("%.1f", v))
        if sl.UpdateSliderVisual then
            sl:UpdateSliderVisual()
        end
    end)

    self.durationSlider = CreateSliderAbsolute(
        self,
        "HLOSH_DurationSlider",
        1,
        20,
        1,
        Healer_LoS_HelperDB.displayDuration or 7,
        -200,
        L["OPTIONS_TIMER_DURATION"] or "Display duration (seconds)",
        function(self, value)
            local v = math.floor(value + 0.5)
            Healer_LoS_HelperDB.displayDuration = v
            if self:GetValue() ~= v then
                self:SetValue(v)
            end
        end,
        false
    )

    self.rangeCheckbox = CreateCheckbox(self, "HLOSH_OutOfRangeCheckbox", L["OPTIONS_SHOW_RANGE_SYMBOL"] or "Show symbol on range error", 40, -270)
    self.rangeCheckbox:SetChecked(Healer_LoS_HelperDB.showOutOfRange)
    self.rangeCheckbox:SetScript("OnClick", function(self)
        Healer_LoS_HelperDB.showOutOfRange = self:GetChecked()
    end)

    self.losNotify = CreateCheckbox(self, "HLOSH_LoSNotifyCheckbox", L["NOTIFY_LOS"] or "Notify target on LoS failure", 40, -305)
    self.losNotify:SetChecked(Healer_LoS_HelperDB.notifyTargetLoS)
    self.losNotify:SetScript("OnClick", function(self)
        Healer_LoS_HelperDB.notifyTargetLoS = self:GetChecked()
    end)

    self.rangeNotify = CreateCheckbox(self, "HLOSH_RangeNotifyCheckbox", L["NOTIFY_RANGE"] or "Notify target on range failure", 40, -340)
    self.rangeNotify:SetChecked(Healer_LoS_HelperDB.notifyTargetRange)
    self.rangeNotify:SetScript("OnClick", function(self)
        Healer_LoS_HelperDB.notifyTargetRange = self:GetChecked()
    end)

    self.messageLanguageDropdown = CreateMessageLanguageDropdown(self, 40, -375)

    self.spamSlider = CreateSliderAbsolute(
        self,
        "HLOSH_SpamSlider",
        1,
        15,
        1,
        Healer_LoS_HelperDB.spamInterval or 5,
        -455,
        L["SPAM_PROTECTION"] or "Message interval (seconds)",
        function(self, value)
            local v = math.floor(value + 0.5)
            Healer_LoS_HelperDB.spamInterval = v
            if self:GetValue() ~= v then
                self:SetValue(v)
            end
        end,
        false
    )

    self.hpThresholdSlider = CreateSliderAbsolute(
        self,
        "HLOSH_HPThresholdSlider",
        1,
        100,
        5,
        Healer_LoS_HelperDB.hpThreshold or 80,
        -535,
        L["OPTIONS_HP_THRESHOLD"] or "Max HP for message (%)",
        function(self, value)
            local v = math.floor((value + 2.5) / 5) * 5
            Healer_LoS_HelperDB.hpThreshold = v
            if self:GetValue() ~= v then
                self:SetValue(v)
            end
        end,
        false
    )

    self.slidersInitialized = true
end

function opt:Open()
    if not self.slidersInitialized and Healer_LoS_HelperDB then
        self:InitSliders()
    end

    if Settings and Settings.OpenToCategory and self.settingsCategoryID then
        Settings.OpenToCategory(self.settingsCategoryID)
        return
    end

    if InterfaceOptionsFrame_OpenToCategory and self.interfaceOptionsRegistered then
        InterfaceOptionsFrame_OpenToCategory(self)
        InterfaceOptionsFrame_OpenToCategory(self)
        return
    end

    self:Show()
end

local function RegisterAddonOptions()
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(opt, opt.name)
        Settings.RegisterAddOnCategory(category)

        opt.close:Hide()
        opt.settingsCategory = category
        if category.GetID then
            opt.settingsCategoryID = category:GetID()
        else
            opt.settingsCategoryID = category.ID
        end
        return
    end

    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(opt)
        opt.close:Hide()
        opt.interfaceOptionsRegistered = true
    end
end

RegisterAddonOptions()
