-- BuffCustomizationEngine.lua - Customize which buffs and debuffs are displayed
-- Part of PluribusHealer addon suite
-- Allows per-player buff priority configuration

local BuffCustomizationEngine = {}
BuffCustomizationEngine.enabled = false
BuffCustomizationEngine.db = nil
BuffCustomizationEngine.buff_config = {}

-- Configuration
BuffCustomizationEngine.config = {
    enabled = true,
    max_buffs_shown = 10,
    max_debuffs_shown = 8,
    priority_mode = "CUSTOM",  -- CUSTOM, ROLE_PRESET, ALL
    hide_expired = true,
    sort_by = "DURATION",  -- DURATION, NAME, TYPE
}

-- Buff categories and priorities
BuffCustomizationEngine.buff_categories = {
    CRITICAL = 2,
    HIGH = 1,
    NORMAL = 0,
    LOW = -1,
}

-- Role-based buff presets
BuffCustomizationEngine.role_presets = {
    HEALER = {
        critical_buffs = {
            "Power Word: Shield",
            "Renew",
            "Rejuvenation",
            "Holy Light",
            "Power Infusion",
        },
        high_priority = {
            "Borrowed Time",
            "Lifebloom",
            "Wild Growth",
            "Rapture",
        },
        ignore_buffs = {
            "Armor",
            "Resistance Aura",
        },
    },
    TANK = {
        critical_buffs = {
            "Shield Wall",
            "Divine Protection",
            "Survival Instincts",
            "Last Stand",
        },
        high_priority = {
            "Thorns",
            "Fortitude",
            "Blessing of Kings",
        },
        ignore_buffs = {
            "Rend",
        },
    },
    DAMAGER = {
        critical_buffs = {
            "Bloodlust",
            "Power Infusion",
            "Bestial Wrath",
        },
        high_priority = {
            "Strength of Earth",
            "Intellect",
        },
        ignore_buffs = {},
    },
}

function BuffCustomizationEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.buff_config then
        self.db.buff_config = {}
    end
    
    if not self.db.buff_priorities then
        self.db.buff_priorities = {}
    end
    
    if not self.db.ignored_buffs then
        self.db.ignored_buffs = {}
    end
    
    self.buff_config = self.db.buff_config
    self.enabled = true
    
    self:Log("Initialized with priority mode: " .. self.config.priority_mode)
end

function BuffCustomizationEngine:SetBuffPriority(buffName, priority)
    if not buffName or type(priority) ~= "number" then
        return false
    end
    
    if not self.buff_config.buff_priorities then
        self.buff_config.buff_priorities = {}
    end
    
    -- Clamp priority between -2 and 2
    priority = math.max(-2, math.min(2, priority))
    
    self.buff_config.buff_priorities[buffName] = priority
    
    self:Log("Buff priority set: " .. buffName .. " -> " .. priority)
    return true
end

function BuffCustomizationEngine:GetBuffPriority(buffName)
    if not buffName or not self.buff_config.buff_priorities then
        return self.buff_categories.NORMAL
    end
    
    return self.buff_config.buff_priorities[buffName] or self.buff_categories.NORMAL
end

function BuffCustomizationEngine:IgnoreBuff(buffName, ignored)
    if not buffName then
        return false
    end
    
    if not self.buff_config.ignored_buffs then
        self.buff_config.ignored_buffs = {}
    end
    
    if ignored then
        self.buff_config.ignored_buffs[buffName] = true
        self:Log("Buff ignored: " .. buffName)
    else
        self.buff_config.ignored_buffs[buffName] = nil
        self:Log("Buff no longer ignored: " .. buffName)
    end
    
    return true
end

function BuffCustomizationEngine:IsBuffIgnored(buffName)
    if not buffName or not self.buff_config.ignored_buffs then
        return false
    end
    
    return self.buff_config.ignored_buffs[buffName] == true
end

function BuffCustomizationEngine:LoadRolePreset(role)
    if not self.role_presets[role] then
        return false
    end
    
    local preset = self.role_presets[role]
    
    -- Clear existing priorities
    if not self.buff_config.buff_priorities then
        self.buff_config.buff_priorities = {}
    end
    
    if not self.buff_config.ignored_buffs then
        self.buff_config.ignored_buffs = {}
    end
    
    self.buff_config.buff_priorities = {}
    self.buff_config.ignored_buffs = {}
    
    -- Load critical buffs
    for _, buffName in ipairs(preset.critical_buffs) do
        self.buff_config.buff_priorities[buffName] = self.buff_categories.CRITICAL
    end
    
    -- Load high priority buffs
    for _, buffName in ipairs(preset.high_priority) do
        self.buff_config.buff_priorities[buffName] = self.buff_categories.HIGH
    end
    
    -- Load ignored buffs
    for _, buffName in ipairs(preset.ignore_buffs) do
        self.buff_config.ignored_buffs[buffName] = true
    end
    
    self:Log("Loaded preset for role: " .. role)
    return true
end

function BuffCustomizationEngine:GetSortedBuffs(buffs)
    if not buffs or #buffs == 0 then
        return {}
    end
    
    local filtered = {}
    
    -- Filter out ignored buffs
    for _, buff in ipairs(buffs) do
        if not self:IsBuffIgnored(buff.name) then
            table.insert(filtered, buff)
        end
    end
    
    -- Sort by priority
    table.sort(filtered, function(a, b)
        local priorityA = self:GetBuffPriority(a.name)
        local priorityB = self:GetBuffPriority(b.name)
        
        if priorityA ~= priorityB then
            return priorityA > priorityB  -- Higher priority first
        end
        
        -- Secondary sort by duration if priorities are equal
        if self.config.sort_by == "DURATION" then
            return (a.duration or 0) > (b.duration or 0)
        end
        
        return a.name < b.name
    end)
    
    -- Limit to max shown
    local maxShown = self.config.max_buffs_shown
    local result = {}
    
    for i = 1, math.min(#filtered, maxShown) do
        table.insert(result, filtered[i])
    end
    
    return result
end

function BuffCustomizationEngine:SetPriorityMode(mode)
    if mode == "CUSTOM" or mode == "ROLE_PRESET" or mode == "ALL" then
        self.config.priority_mode = mode
        self:Log("Priority mode set to: " .. mode)
        return true
    end
    return false
end

function BuffCustomizationEngine:SetMaxBuffsShown(count)
    if count and count > 0 and count <= 50 then
        self.config.max_buffs_shown = count
        self:Log("Max buffs shown: " .. count)
        return true
    end
    return false
end

function BuffCustomizationEngine:SetMaxDebuffsShown(count)
    if count and count > 0 and count <= 50 then
        self.config.max_debuffs_shown = count
        self:Log("Max debuffs shown: " .. count)
        return true
    end
    return false
end

function BuffCustomizationEngine:ExportConfig()
    local export = {
        priorities = self.buff_config.buff_priorities or {},
        ignored = self.buff_config.ignored_buffs or {},
        mode = self.config.priority_mode,
        max_buffs = self.config.max_buffs_shown,
        max_debuffs = self.config.max_debuffs_shown,
    }
    return export
end

function BuffCustomizationEngine:ImportConfig(configData)
    if not configData or type(configData) ~= "table" then
        return false
    end
    
    if configData.priorities then
        self.buff_config.buff_priorities = configData.priorities
    end
    
    if configData.ignored then
        self.buff_config.ignored_buffs = configData.ignored
    end
    
    if configData.mode then
        self:SetPriorityMode(configData.mode)
    end
    
    if configData.max_buffs then
        self:SetMaxBuffsShown(configData.max_buffs)
    end
    
    if configData.max_debuffs then
        self:SetMaxDebuffsShown(configData.max_debuffs)
    end
    
    self:Log("Configuration imported")
    return true
end

function BuffCustomizationEngine:GetStatus()
    local priorityCount = 0
    local ignoredCount = 0
    
    if self.buff_config.buff_priorities then
        for _ in pairs(self.buff_config.buff_priorities) do
            priorityCount = priorityCount + 1
        end
    end
    
    if self.buff_config.ignored_buffs then
        for _ in pairs(self.buff_config.ignored_buffs) do
            ignoredCount = ignoredCount + 1
        end
    end
    
    return {
        enabled = self.enabled,
        priority_mode = self.config.priority_mode,
        max_buffs_shown = self.config.max_buffs_shown,
        max_debuffs_shown = self.config.max_debuffs_shown,
        priority_count = priorityCount,
        ignored_count = ignoredCount,
    }
end

function BuffCustomizationEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[BuffCustomizationEngine] " .. message)
    else
        print("[BuffCustomizationEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_BUFFCUSTOM1 = "/buffcustom"
    SlashCmdList["BUFFCUSTOM"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "priority" then
            local buff, priority = args:match("^(.+)%s+([+-]?%d)$")
            if buff and priority then
                BuffCustomizationEngine:SetBuffPriority(buff, tonumber(priority))
                print("Priority set: " .. buff .. " -> " .. priority)
            else
                print("Usage: /buffcustom priority <name> <-2 to 2>")
            end
        elseif cmd == "ignore" then
            local buffName = args
            if buffName and buffName ~= "" then
                BuffCustomizationEngine:IgnoreBuff(buffName, true)
                print("Buff ignored: " .. buffName)
            else
                print("Usage: /buffcustom ignore <name>")
            end
        elseif cmd == "unignore" then
            local buffName = args
            if buffName and buffName ~= "" then
                BuffCustomizationEngine:IgnoreBuff(buffName, false)
                print("Buff no longer ignored: " .. buffName)
            else
                print("Usage: /buffcustom unignore <name>")
            end
        elseif cmd == "preset" then
            if args and (args == "HEALER" or args == "TANK" or args == "DAMAGER") then
                BuffCustomizationEngine:LoadRolePreset(args)
                print("Loaded preset: " .. args)
            else
                print("Usage: /buffcustom preset <HEALER|TANK|DAMAGER>")
            end
        elseif cmd == "mode" then
            if args and (args == "CUSTOM" or args == "ROLE_PRESET" or args == "ALL") then
                BuffCustomizationEngine:SetPriorityMode(args)
                print("Mode: " .. args)
            else
                print("Usage: /buffcustom mode <CUSTOM|ROLE_PRESET|ALL>")
            end
        elseif cmd == "maxbuffs" then
            if args and tonumber(args) then
                BuffCustomizationEngine:SetMaxBuffsShown(tonumber(args))
                print("Max buffs shown: " .. args)
            else
                print("Usage: /buffcustom maxbuffs <number>")
            end
        elseif cmd == "maxdebuffs" then
            if args and tonumber(args) then
                BuffCustomizationEngine:SetMaxDebuffsShown(tonumber(args))
                print("Max debuffs shown: " .. args)
            else
                print("Usage: /buffcustom maxdebuffs <number>")
            end
        elseif cmd == "status" then
            local status = BuffCustomizationEngine:GetStatus()
            print("Buff Customization Engine:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Buff Customization Commands:")
            print("  /buffcustom priority <name> <-2 to 2> - Set buff priority")
            print("  /buffcustom ignore <name> - Ignore buff")
            print("  /buffcustom unignore <name> - Stop ignoring buff")
            print("  /buffcustom preset <HEALER|TANK|DAMAGER> - Load role preset")
            print("  /buffcustom mode <CUSTOM|ROLE_PRESET|ALL> - Set priority mode")
            print("  /buffcustom maxbuffs <number> - Set max buffs shown")
            print("  /buffcustom maxdebuffs <number> - Set max debuffs shown")
            print("  /buffcustom status - Show system status")
        end
    end
end

return BuffCustomizationEngine
