-- QuestConfigurationEngine.lua - Configuration system for quest display
-- Part of PluribusQuestie addon suite
-- Manages toggles, filters, profiles, and display options

local QuestConfigurationEngine = {}
QuestConfigurationEngine.enabled = false
QuestConfigurationEngine.db = nil
QuestConfigurationEngine.settings = {}
QuestConfigurationEngine.profiles = {}
QuestConfigurationEngine.active_profile = "default"

-- Configuration
QuestConfigurationEngine.config = {
    enabled = true,
    max_profiles = 10,
}

function QuestConfigurationEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusQuestie")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.settings then
        self.db.settings = self:GetDefaultSettings()
    end
    
    if not self.db.profiles then
        self.db.profiles = {}
    end
    
    self.settings = self.db.settings
    self.profiles = self.db.profiles
    self.enabled = true
    
    self:Log("Initialized quest configuration engine")
end

function QuestConfigurationEngine:GetDefaultSettings()
    return {
        -- Display Toggles
        show_quest_icons = true,
        show_map_markers = true,
        show_minimap_markers = true,
        show_objectives = true,
        show_completed = false,
        show_abandoned = false,
        
        -- Filter Settings
        level_filter_enabled = false,
        level_filter_min = 1,
        level_filter_max = 60,
        
        zone_filter_enabled = false,
        zone_filter_zones = {},
        
        type_filter_enabled = false,
        type_filter_types = {},
        
        reward_filter_enabled = false,
        reward_filter_min_gold = 0,
        reward_filter_min_xp = 0,
        
        difficulty_filter_enabled = false,
        difficulty_filter_difficulty = "normal",
        
        status_filter_enabled = false,
        status_filter_statuses = {},
        
        -- Sorting
        sort_by = "level",  -- level, name, zone, rewards, difficulty
        sort_ascending = true,
        
        -- Display Options
        compact_mode = false,
        show_quest_level = true,
        show_quest_zone = true,
        show_quest_rewards = true,
        show_quest_progress = true,
        
        -- Color Settings
        color_available = "|cffffff00",  -- Yellow
        color_completed = "|cff00ff00",  -- Green
        color_in_progress = "|cffff00ff", -- Purple
        color_failed = "|cffff0000",    -- Red
        
        -- Misc
        auto_track_quests = true,
        waypoint_distance_threshold = 100,  -- yards
        guidance_enabled = true,
        enable_notifications = true,
    }
end

function QuestConfigurationEngine:SetSetting(key, value)
    if not key then
        return false
    end
    
    self.settings[key] = value
    self:Log("Setting changed: " .. key .. " = " .. tostring(value))
    
    return true
end

function QuestConfigurationEngine:GetSetting(key, defaultValue)
    if not key then
        return defaultValue
    end
    
    return self.settings[key] ~= nil and self.settings[key] or defaultValue
end

function QuestConfigurationEngine:GetAllSettings()
    return self.settings
end

-- Toggle functions
function QuestConfigurationEngine:ToggleQuestIcons()
    self.settings.show_quest_icons = not self.settings.show_quest_icons
    self:Log("Quest icons: " .. (self.settings.show_quest_icons and "enabled" or "disabled"))
    return self.settings.show_quest_icons
end

function QuestConfigurationEngine:ToggleMapMarkers()
    self.settings.show_map_markers = not self.settings.show_map_markers
    self:Log("Map markers: " .. (self.settings.show_map_markers and "enabled" or "disabled"))
    return self.settings.show_map_markers
end

function QuestConfigurationEngine:ToggleMinimapMarkers()
    self.settings.show_minimap_markers = not self.settings.show_minimap_markers
    self:Log("Minimap markers: " .. (self.settings.show_minimap_markers and "enabled" or "disabled"))
    return self.settings.show_minimap_markers
end

function QuestConfigurationEngine:ToggleObjectiveTracking()
    self.settings.show_objectives = not self.settings.show_objectives
    self:Log("Objective tracking: " .. (self.settings.show_objectives and "enabled" or "disabled"))
    return self.settings.show_objectives
end

function QuestConfigurationEngine:ToggleCompletedDisplay()
    self.settings.show_completed = not self.settings.show_completed
    self:Log("Completed quests: " .. (self.settings.show_completed and "shown" or "hidden"))
    return self.settings.show_completed
end

function QuestConfigurationEngine:ToggleGuidance()
    self.settings.guidance_enabled = not self.settings.guidance_enabled
    self:Log("Guidance: " .. (self.settings.guidance_enabled and "enabled" or "disabled"))
    return self.settings.guidance_enabled
end

-- Filter Management
function QuestConfigurationEngine:SetLevelFilter(minLevel, maxLevel)
    self.settings.level_filter_min = minLevel or 1
    self.settings.level_filter_max = maxLevel or 60
    self.settings.level_filter_enabled = true
    
    self:Log("Level filter set: " .. minLevel .. " - " .. maxLevel)
    return true
end

function QuestConfigurationEngine:DisableLevelFilter()
    self.settings.level_filter_enabled = false
    self:Log("Level filter disabled")
    return true
end

function QuestConfigurationEngine:SetZoneFilter(zoneList)
    if not zoneList or #zoneList == 0 then
        self.settings.zone_filter_enabled = false
        return true
    end
    
    self.settings.zone_filter_zones = zoneList
    self.settings.zone_filter_enabled = true
    
    self:Log("Zone filter set: " .. #zoneList .. " zones")
    return true
end

function QuestConfigurationEngine:SetTypeFilter(typeList)
    if not typeList or #typeList == 0 then
        self.settings.type_filter_enabled = false
        return true
    end
    
    self.settings.type_filter_types = typeList
    self.settings.type_filter_enabled = true
    
    self:Log("Type filter set: " .. #typeList .. " types")
    return true
end

function QuestConfigurationEngine:SetRewardFilter(minGold, minXP)
    self.settings.reward_filter_min_gold = minGold or 0
    self.settings.reward_filter_min_xp = minXP or 0
    self.settings.reward_filter_enabled = true
    
    self:Log("Reward filter set: " .. minGold .. "g, " .. minXP .. " XP")
    return true
end

function QuestConfigurationEngine:SetDifficultyFilter(difficulty)
    self.settings.difficulty_filter_difficulty = difficulty or "normal"
    self.settings.difficulty_filter_enabled = true
    
    self:Log("Difficulty filter set: " .. difficulty)
    return true
end

-- Sorting
function QuestConfigurationEngine:SetSortOrder(sortBy, ascending)
    self.settings.sort_by = sortBy or "level"
    self.settings.sort_ascending = ascending == nil and true or ascending
    
    self:Log("Sort order set: " .. sortBy .. (self.settings.sort_ascending and " (asc)" or " (desc)"))
    return true
end

-- Profile Management
function QuestConfigurationEngine:CreateProfile(profileName)
    if not profileName then
        return false
    end
    
    if #self.profiles >= self.config.max_profiles then
        self:Log("Max profiles reached")
        return false
    end
    
    local profile = {
        name = profileName,
        settings = self:DeepCopy(self.settings),
        created_at = GetTime(),
        last_modified = GetTime(),
    }
    
    table.insert(self.profiles, profile)
    self:Log("Profile created: " .. profileName)
    
    return true
end

function QuestConfigurationEngine:GetProfile(profileName)
    for _, profile in ipairs(self.profiles) do
        if profile.name == profileName then
            return profile
        end
    end
    
    return nil
end

function QuestConfigurationEngine:LoadProfile(profileName)
    local profile = self:GetProfile(profileName)
    if not profile then
        self:Log("Profile not found: " .. profileName)
        return false
    end
    
    self.settings = self:DeepCopy(profile.settings)
    self.active_profile = profileName
    
    self:Log("Profile loaded: " .. profileName)
    return true
end

function QuestConfigurationEngine:SaveProfile(profileName)
    local profile = self:GetProfile(profileName)
    if not profile then
        return false
    end
    
    profile.settings = self:DeepCopy(self.settings)
    profile.last_modified = GetTime()
    
    self:Log("Profile saved: " .. profileName)
    return true
end

function QuestConfigurationEngine:DeleteProfile(profileName)
    for i, profile in ipairs(self.profiles) do
        if profile.name == profileName then
            table.remove(self.profiles, i)
            self:Log("Profile deleted: " .. profileName)
            return true
        end
    end
    
    return false
end

function QuestConfigurationEngine:ListProfiles()
    local list = {}
    
    for _, profile in ipairs(self.profiles) do
        table.insert(list, {
            name = profile.name,
            created_at = profile.created_at,
            last_modified = profile.last_modified,
        })
    end
    
    return list
end

function QuestConfigurationEngine:GetActiveProfile()
    return self.active_profile
end

-- Utility functions
function QuestConfigurationEngine:DeepCopy(table)
    if type(table) ~= "table" then
        return table
    end
    
    local copy = {}
    
    for key, value in pairs(table) do
        if type(value) == "table" then
            copy[key] = self:DeepCopy(value)
        else
            copy[key] = value
        end
    end
    
    return copy
end

function QuestConfigurationEngine:ResetToDefaults()
    self.settings = self:GetDefaultSettings()
    self:Log("Settings reset to defaults")
    return true
end

function QuestConfigurationEngine:ExportSettings()
    return self:DeepCopy(self.settings)
end

function QuestConfigurationEngine:ImportSettings(importedSettings)
    if not importedSettings or type(importedSettings) ~= "table" then
        return false
    end
    
    for key, value in pairs(importedSettings) do
        self.settings[key] = value
    end
    
    self:Log("Settings imported")
    return true
end

function QuestConfigurationEngine:GetStatus()
    return {
        enabled = self.enabled,
        active_profile = self.active_profile,
        total_profiles = #self.profiles,
        settings_count = table.getn(self.settings),
    }
end

function QuestConfigurationEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[QuestConfigurationEngine] " .. message)
    else
        print("[QuestConfigurationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_QUESTCONFIG1 = "/questconfig"
    SlashCmdList["QUESTCONFIG"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "toggle" then
            if args == "icons" then
                QuestConfigurationEngine:ToggleQuestIcons()
                print("Quest icons toggled")
            elseif args == "map" then
                QuestConfigurationEngine:ToggleMapMarkers()
                print("Map markers toggled")
            elseif args == "minimap" then
                QuestConfigurationEngine:ToggleMinimapMarkers()
                print("Minimap markers toggled")
            elseif args == "objectives" then
                QuestConfigurationEngine:ToggleObjectiveTracking()
                print("Objective tracking toggled")
            else
                print("Usage: /questconfig toggle [icons|map|minimap|objectives]")
            end
        elseif cmd == "profile" then
            local action, profileName = args:match("^(%S+)%s+(.*)$")
            
            if action == "create" then
                if profileName ~= "" then
                    QuestConfigurationEngine:CreateProfile(profileName)
                    print("Profile created: " .. profileName)
                else
                    print("Usage: /questconfig profile create <name>")
                end
            elseif action == "load" then
                if profileName ~= "" then
                    if QuestConfigurationEngine:LoadProfile(profileName) then
                        print("Profile loaded: " .. profileName)
                    else
                        print("Profile not found: " .. profileName)
                    end
                else
                    print("Usage: /questconfig profile load <name>")
                end
            elseif action == "save" then
                if profileName ~= "" then
                    if QuestConfigurationEngine:SaveProfile(profileName) then
                        print("Profile saved: " .. profileName)
                    else
                        print("Profile not found: " .. profileName)
                    end
                else
                    print("Usage: /questconfig profile save <name>")
                end
            elseif action == "delete" then
                if profileName ~= "" then
                    QuestConfigurationEngine:DeleteProfile(profileName)
                    print("Profile deleted: " .. profileName)
                else
                    print("Usage: /questconfig profile delete <name>")
                end
            elseif action == "list" then
                local profiles = QuestConfigurationEngine:ListProfiles()
                print("Profiles: " .. #profiles)
                for _, profile in ipairs(profiles) do
                    print("  - " .. profile.name)
                end
            else
                print("Usage: /questconfig profile [create|load|save|delete|list] <name>")
            end
        elseif cmd == "reset" then
            QuestConfigurationEngine:ResetToDefaults()
            print("Settings reset to defaults")
        elseif cmd == "status" then
            local status = QuestConfigurationEngine:GetStatus()
            print("Quest Configuration:")
            print("  Active Profile: " .. status.active_profile)
            print("  Total Profiles: " .. status.total_profiles)
            print("  Settings Count: " .. status.settings_count)
        else
            print("Quest Configuration Commands:")
            print("  /questconfig toggle [icons|map|minimap|objectives] - Toggle display")
            print("  /questconfig profile create <name> - Create profile")
            print("  /questconfig profile load <name> - Load profile")
            print("  /questconfig profile save <name> - Save profile")
            print("  /questconfig profile delete <name> - Delete profile")
            print("  /questconfig profile list - List profiles")
            print("  /questconfig reset - Reset to defaults")
            print("  /questconfig status - Show status")
        end
    end
end

return QuestConfigurationEngine
