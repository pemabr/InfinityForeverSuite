-- QuestPreferencesEngine.lua - User quest preferences and settings
-- Part of InfinityQuestie addon suite
-- Manages user preferences, settings, and UI customization

local QuestPreferencesEngine = {}
QuestPreferencesEngine.enabled = false
QuestPreferencesEngine.db = nil
QuestPreferencesEngine.preferences = {}
QuestPreferencesEngine.preferences_config = {}
QuestPreferencesEngine.preference_profiles = {}

-- Configuration
QuestPreferencesEngine.config = {
    enabled = true,
    allow_profiles = true,
    auto_save = true,
}

-- Default preferences
QuestPreferencesEngine.default_preferences = {
    ui = {
        font_size = 12,
        theme = "dark",
        transparency = 0.8,
        compact_mode = false,
        show_tooltips = true,
    },
    notifications = {
        enable_sound = true,
        enable_visual = true,
        notify_level = "medium",
        notify_expired = true,
        notify_new = true,
    },
    display = {
        sort_method = "level",
        items_per_page = 20,
        show_difficulty = true,
        show_rewards = true,
        show_progress = true,
    },
    filters = {
        default_level_range = { min = 1, max = 60 },
        default_difficulty = "all",
        hide_completed = false,
        hide_unavailable = false,
    },
    performance = {
        enable_caching = true,
        cache_size = 100,
        update_frequency = 1,
        low_memory_mode = false,
    },
    tracking = {
        track_time = true,
        track_efficiency = true,
        auto_track = true,
        track_conflicts = true,
    },
}

function QuestPreferencesEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.preferences then
        self.db.preferences = {}
    end
    
    if not self.db.preferences_config then
        self.db.preferences_config = {}
    end
    
    if not self.db.preference_profiles then
        self.db.preference_profiles = {}
    end
    
    self.preferences = self.db.preferences
    self.preferences_config = self.db.preferences_config
    self.preference_profiles = self.db.preference_profiles
    
    -- Initialize with defaults if empty
    if not next(self.preferences) then
        self:ResetToDefaults()
    end
    
    self.enabled = true
    
    self:Log("Initialized preferences engine")
end

function QuestPreferencesEngine:ResetToDefaults()
    self.preferences = {}
    for category, settings in pairs(self.default_preferences) do
        self.preferences[category] = {}
        for key, value in pairs(settings) do
            self.preferences[category][key] = value
        end
    end
    
    self.db.preferences = self.preferences
    self:Log("Reset preferences to defaults")
    
    return true
end

function QuestPreferencesEngine:GetPreference(category, key)
    if not category or not key then
        return nil
    end
    
    if not self.preferences[category] then
        return nil
    end
    
    return self.preferences[category][key]
end

function QuestPreferencesEngine:SetPreference(category, key, value)
    if not category or not key or value == nil then
        return false
    end
    
    if not self.preferences[category] then
        self.preferences[category] = {}
    end
    
    self.preferences[category][key] = value
    self:Log("Set preference: " .. category .. "." .. key .. " = " .. tostring(value))
    
    return true
end

function QuestPreferencesEngine:GetCategory(category)
    if not category then
        return nil
    end
    
    return self.preferences[category]
end

function QuestPreferencesEngine:SetCategory(category, settings)
    if not category or not settings then
        return false
    end
    
    self.preferences[category] = {}
    for key, value in pairs(settings) do
        self.preferences[category][key] = value
    end
    
    self:Log("Updated preference category: " .. category)
    
    return true
end

function QuestPreferencesEngine:GetUIPreferences()
    return self:GetCategory("ui")
end

function QuestPreferencesEngine:SetUIPreferences(uiSettings)
    return self:SetCategory("ui", uiSettings)
end

function QuestPreferencesEngine:GetNotificationPreferences()
    return self:GetCategory("notifications")
end

function QuestPreferencesEngine:SetNotificationPreferences(notifSettings)
    return self:SetCategory("notifications", notifSettings)
end

function QuestPreferencesEngine:GetDisplayPreferences()
    return self:GetCategory("display")
end

function QuestPreferencesEngine:SetDisplayPreferences(displaySettings)
    return self:SetCategory("display", displaySettings)
end

function QuestPreferencesEngine:GetFilterPreferences()
    return self:GetCategory("filters")
end

function QuestPreferencesEngine:SetFilterPreferences(filterSettings)
    return self:SetCategory("filters", filterSettings)
end

function QuestPreferencesEngine:GetPerformancePreferences()
    return self:GetCategory("performance")
end

function QuestPreferencesEngine:SetPerformancePreferences(perfSettings)
    return self:SetCategory("performance", perfSettings)
end

function QuestPreferencesEngine:SaveProfile(profileName)
    if not profileName then
        return false
    end
    
    local profile = {
        name = profileName,
        preferences = {},
        created_at = GetTime(),
    }
    
    -- Deep copy preferences
    for category, settings in pairs(self.preferences) do
        profile.preferences[category] = {}
        for key, value in pairs(settings) do
            profile.preferences[category][key] = value
        end
    end
    
    self.preference_profiles[profileName] = profile
    self:Log("Saved preference profile: " .. profileName)
    
    return true
end

function QuestPreferencesEngine:LoadProfile(profileName)
    if not profileName or not self.preference_profiles[profileName] then
        return false
    end
    
    local profile = self.preference_profiles[profileName]
    
    -- Restore preferences from profile
    self.preferences = {}
    for category, settings in pairs(profile.preferences) do
        self.preferences[category] = {}
        for key, value in pairs(settings) do
            self.preferences[category][key] = value
        end
    end
    
    self.db.preferences = self.preferences
    self:Log("Loaded preference profile: " .. profileName)
    
    return true
end

function QuestPreferencesEngine:DeleteProfile(profileName)
    if not profileName or not self.preference_profiles[profileName] then
        return false
    end
    
    self.preference_profiles[profileName] = nil
    self:Log("Deleted preference profile: " .. profileName)
    
    return true
end

function QuestPreferencesEngine:GetProfiles()
    local profiles = {}
    
    for profileName, profile in pairs(self.preference_profiles) do
        table.insert(profiles, {
            name = profileName,
            created_at = profile.created_at,
        })
    end
    
    return profiles
end

function QuestPreferencesEngine:ExportPreferences()
    local export = {}
    
    for category, settings in pairs(self.preferences) do
        export[category] = {}
        for key, value in pairs(settings) do
            export[category][key] = value
        end
    end
    
    return export
end

function QuestPreferencesEngine:ImportPreferences(importData)
    if not importData then
        return false
    end
    
    -- Validate and merge
    for category, settings in pairs(importData) do
        if type(settings) == "table" then
            if not self.preferences[category] then
                self.preferences[category] = {}
            end
            
            for key, value in pairs(settings) do
                self.preferences[category][key] = value
            end
        end
    end
    
    self.db.preferences = self.preferences
    self:Log("Imported preferences")
    
    return true
end

function QuestPreferencesEngine:GetPreferenceSummary()
    local summary = {
        total_prefs = 0,
        profiles = 0,
        categories = 0,
    }
    
    for category, settings in pairs(self.preferences) do
        summary.categories = summary.categories + 1
        for _ in pairs(settings) do
            summary.total_prefs = summary.total_prefs + 1
        end
    end
    
    for _ in pairs(self.preference_profiles) do
        summary.profiles = summary.profiles + 1
    end
    
    return summary
end

function QuestPreferencesEngine:GetStatus()
    local summary = self:GetPreferenceSummary()
    
    return {
        enabled = self.enabled,
        total_preferences = summary.total_prefs,
        categories = summary.categories,
        saved_profiles = summary.profiles,
    }
end

function QuestPreferencesEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[QuestPreferencesEngine] " .. message)
    else
        print("[QuestPreferencesEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTPREFS1 = "/questprefs"
    SlashCmdList["QUESTPREFS"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "get" then
            local cat, key = args:match("^(%S+)%s+(%S+)$")
            if cat and key then
                local value = QuestPreferencesEngine:GetPreference(cat, key)
                print(cat .. "." .. key .. " = " .. tostring(value))
            else
                print("Usage: /questprefs get <category> <key>")
            end
        elseif cmd == "set" then
            local cat, key, val = args:match("^(%S+)%s+(%S+)%s+(.+)$")
            if cat and key and val then
                QuestPreferencesEngine:SetPreference(cat, key, val)
                print("Set " .. cat .. "." .. key .. " = " .. val)
            else
                print("Usage: /questprefs set <category> <key> <value>")
            end
        elseif cmd == "category" then
            local cat = args
            if cat ~= "" then
                local settings = QuestPreferencesEngine:GetCategory(cat)
                if settings then
                    print("Category: " .. cat)
                    for key, value in pairs(settings) do
                        print("  " .. key .. " = " .. tostring(value))
                    end
                else
                    print("Category not found")
                end
            else
                print("Usage: /questprefs category <name>")
            end
        elseif cmd == "reset" then
            QuestPreferencesEngine:ResetToDefaults()
            print("Reset preferences to defaults")
        elseif cmd == "save" then
            if args ~= "" then
                QuestPreferencesEngine:SaveProfile(args)
                print("Saved profile: " .. args)
            else
                print("Usage: /questprefs save <name>")
            end
        elseif cmd == "load" then
            if args ~= "" then
                local success = QuestPreferencesEngine:LoadProfile(args)
                print("Load profile: " .. (success and "Success" or "Failed"))
            else
                print("Usage: /questprefs load <name>")
            end
        elseif cmd == "profiles" then
            local profiles = QuestPreferencesEngine:GetProfiles()
            print("Saved Profiles (" .. #profiles .. "):")
            for i, profile in ipairs(profiles) do
                print(i .. ". " .. profile.name)
            end
        elseif cmd == "status" then
            local status = QuestPreferencesEngine:GetStatus()
            print("Quest Preferences Status:")
            print("  Enabled: " .. (status.enabled and "Yes" or "No"))
            print("  Total: " .. status.total_preferences)
            print("  Categories: " .. status.categories)
            print("  Profiles: " .. status.saved_profiles)
        else
            print("Quest Preferences Commands:")
            print("  /questprefs get <cat> <key> - Get preference")
            print("  /questprefs set <cat> <key> <val> - Set preference")
            print("  /questprefs category <name> - Show category")
            print("  /questprefs reset - Reset to defaults")
            print("  /questprefs save <name> - Save profile")
            print("  /questprefs load <name> - Load profile")
            print("  /questprefs profiles - List profiles")
            print("  /questprefs status - Show engine status")
        end
    end
end

return QuestPreferencesEngine
