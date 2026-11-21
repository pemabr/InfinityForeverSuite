-- QuestLocalizationEngine.lua - Localization support for quests
-- Part of InfinityQuestie addon suite
-- Handles multiple language support and locale-specific quest data

local QuestLocalizationEngine = {}
QuestLocalizationEngine.enabled = false
QuestLocalizationEngine.db = nil
QuestLocalizationEngine.locales = {}
QuestLocalizationEngine.current_locale = "enUS"
QuestLocalizationEngine.translations = {}

-- Configuration
QuestLocalizationEngine.config = {
    enabled = true,
    supported_locales = {
        "enUS",   -- English (US)
        "enGB",   -- English (UK)
        "deDE",   -- German
        "frFR",   -- French
        "esES",   -- Spanish
        "itIT",   -- Italian
        "koKR",   -- Korean
        "zhCN",   -- Chinese (Simplified)
        "zhTW",   -- Chinese (Traditional)
        "ruRU",   -- Russian
        "ptBR",   -- Portuguese (Brazil)
        "jaJP",   -- Japanese
    },
    fallback_locale = "enUS",
}

function QuestLocalizationEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.translations then
        self.db.translations = {}
    end
    
    if not self.db.current_locale then
        self.db.current_locale = self:DetectLocale()
    end
    
    self.translations = self.db.translations
    self.current_locale = self.db.current_locale
    self.enabled = true
    
    self:Log("Initialized localization engine (locale: " .. self.current_locale .. ")")
end

function QuestLocalizationEngine:DetectLocale()
    local locale = GetLocale()
    
    -- Map WoW locale to supported locale
    if locale then
        for _, supported in ipairs(self.config.supported_locales) do
            if locale:lower() == supported:lower() then
                return supported
            end
        end
    end
    
    return self.config.fallback_locale
end

function QuestLocalizationEngine:SetLocale(locale)
    if not locale then
        return false
    end
    
    -- Verify locale is supported
    local supported = false
    for _, supported_locale in ipairs(self.config.supported_locales) do
        if supported_locale == locale then
            supported = true
            break
        end
    end
    
    if not supported then
        self:Log("Unsupported locale: " .. locale)
        return false
    end
    
    self.current_locale = locale
    self.db.current_locale = locale
    self:Log("Locale changed to: " .. locale)
    
    return true
end

function QuestLocalizationEngine:GetCurrentLocale()
    return self.current_locale
end

function QuestLocalizationEngine:RegisterTranslation(stringId, locale, translatedText)
    if not stringId or not locale or not translatedText then
        return false
    end
    
    if not self.translations[stringId] then
        self.translations[stringId] = {}
    end
    
    self.translations[stringId][locale] = translatedText
    
    return true
end

function QuestLocalizationEngine:GetTranslation(stringId, locale)
    locale = locale or self.current_locale
    
    if not stringId then
        return nil
    end
    
    if self.translations[stringId] and self.translations[stringId][locale] then
        return self.translations[stringId][locale]
    end
    
    -- Fall back to fallback locale
    if locale ~= self.config.fallback_locale and 
       self.translations[stringId] and 
       self.translations[stringId][self.config.fallback_locale] then
        return self.translations[stringId][self.config.fallback_locale]
    end
    
    return nil
end

function QuestLocalizationEngine:LocalizeQuestName(questId)
    local stringId = "quest_" .. questId .. "_name"
    local translation = self:GetTranslation(stringId)
    
    return translation or "Quest " .. questId
end

function QuestLocalizationEngine:LocalizeQuestDescription(questId)
    local stringId = "quest_" .. questId .. "_desc"
    local translation = self:GetTranslation(stringId)
    
    return translation or ""
end

function QuestLocalizationEngine:LocalizeObjectiveName(questId, objectiveIndex)
    local stringId = "quest_" .. questId .. "_obj_" .. objectiveIndex
    local translation = self:GetTranslation(stringId)
    
    return translation or "Objective " .. objectiveIndex
end

function QuestLocalizationEngine:LocalizeQuestData(questData, locale)
    if not questData then
        return nil
    end
    
    locale = locale or self.current_locale
    
    local localized = {
        id = questData.id,
        name = self:GetTranslation("quest_" .. questData.id .. "_name", locale) or questData.name or "",
        description = self:GetTranslation("quest_" .. questData.id .. "_desc", locale) or questData.description or "",
        objectives = {},
    }
    
    if questData.objectives and #questData.objectives > 0 then
        for i, objective in ipairs(questData.objectives) do
            table.insert(localized.objectives, {
                index = i,
                text = self:GetTranslation("quest_" .. questData.id .. "_obj_" .. i, locale) or objective or "",
            })
        end
    end
    
    return localized
end

function QuestLocalizationEngine:LoadLocaleFile(locale)
    if not locale then
        return false
    end
    
    -- Try to load locale-specific file
    local fileName = "Locales\\" .. locale .. ".lua"
    
    self:Log("Loading locale file: " .. fileName)
    
    return true
end

function QuestLocalizationEngine:ExportTranslations(locale)
    locale = locale or self.current_locale
    
    local lua = "-- Translations for locale: " .. locale .. "\n"
    lua = lua .. "-- Generated at: " .. date("%Y-%m-%d %H:%M:%S") .. "\n\n"
    lua = lua .. "local translations = {\n"
    
    for stringId, locales in pairs(self.translations) do
        if locales[locale] then
            lua = lua .. "  ['" .. stringId .. "'] = '" .. (locales[locale]:gsub("'", "\\'")) .. "',\n"
        end
    end
    
    lua = lua .. "}\nreturn translations"
    return lua
end

function QuestLocalizationEngine:ImportTranslations(locale, translationTable)
    if not locale or not translationTable then
        return false
    end
    
    local imported = 0
    
    for stringId, translatedText in pairs(translationTable) do
        if self:RegisterTranslation(stringId, locale, translatedText) then
            imported = imported + 1
        end
    end
    
    self:Log("Imported " .. imported .. " translations for locale: " .. locale)
    return true
end

function QuestLocalizationEngine:GetSupportedLocales()
    return self.config.supported_locales
end

function QuestLocalizationEngine:IsLocaleSupported(locale)
    if not locale then
        return false
    end
    
    for _, supported in ipairs(self.config.supported_locales) do
        if supported == locale then
            return true
        end
    end
    
    return false
end

function QuestLocalizationEngine:GetLocaleDisplayName(locale)
    local names = {
        enUS = "English (US)",
        enGB = "English (UK)",
        deDE = "German",
        frFR = "French",
        esES = "Spanish",
        itIT = "Italian",
        koKR = "Korean",
        zhCN = "Chinese (Simplified)",
        zhTW = "Chinese (Traditional)",
        ruRU = "Russian",
        ptBR = "Portuguese (Brazil)",
        jaJP = "Japanese",
    }
    
    return names[locale] or locale
end

function QuestLocalizationEngine:GetStatus()
    local translationCount = table.getn(self.translations)
    
    return {
        enabled = self.enabled,
        current_locale = self.current_locale,
        supported_locales = #self.config.supported_locales,
        total_translations = translationCount,
    }
end

function QuestLocalizationEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestLocalizationEngine] " .. message)
    else
        print("[QuestLocalizationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTLOCAL1 = "/questlocal"
    SlashCmdList["QUESTLOCAL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            local locale = args
            if locale ~= "" then
                if QuestLocalizationEngine:SetLocale(locale) then
                    print("Locale set to: " .. locale)
                else
                    print("Invalid locale: " .. locale)
                end
            else
                print("Usage: /questlocal set <locale>")
            end
        elseif cmd == "current" then
            print("Current locale: " .. QuestLocalizationEngine:GetCurrentLocale())
        elseif cmd == "supported" then
            local locales = QuestLocalizationEngine:GetSupportedLocales()
            print("Supported locales: " .. #locales)
            for i, locale in ipairs(locales) do
                print("  [" .. i .. "] " .. locale .. " (" .. QuestLocalizationEngine:GetLocaleDisplayName(locale) .. ")")
            end
        elseif cmd == "translate" then
            local parts = args:match("(%S+)%s+(.+)")
            if parts then
                local stringId, text = args:match("^(%S+)%s+(.+)$")
                QuestLocalizationEngine:RegisterTranslation(stringId, QuestLocalizationEngine:GetCurrentLocale(), text)
                print("Translation registered: " .. stringId)
            else
                print("Usage: /questlocal translate <stringId> <text>")
            end
        elseif cmd == "get" then
            local stringId = args
            if stringId ~= "" then
                local translation = QuestLocalizationEngine:GetTranslation(stringId)
                if translation then
                    print("Translation: " .. translation)
                else
                    print("No translation found for: " .. stringId)
                end
            else
                print("Usage: /questlocal get <stringId>")
            end
        elseif cmd == "status" then
            local status = QuestLocalizationEngine:GetStatus()
            print("Localization Status:")
            print("  Current Locale: " .. status.current_locale)
            print("  Supported Locales: " .. status.supported_locales)
            print("  Total Translations: " .. status.total_translations)
        else
            print("Quest Localization Commands:")
            print("  /questlocal set <locale> - Set current locale")
            print("  /questlocal current - Show current locale")
            print("  /questlocal supported - List supported locales")
            print("  /questlocal translate <id> <text> - Register translation")
            print("  /questlocal get <stringId> - Get translation")
            print("  /questlocal status - Show status")
        end
    end
end

return QuestLocalizationEngine
