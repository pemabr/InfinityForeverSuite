-- AuraHighlightEngine.lua - Track and display aura/debuff highlighting
-- Part of PluribusHealer addon suite
-- Maintains player aura state and provides highlighting for critical buffs/debuffs

local AuraHighlightEngine = {}
AuraHighlightEngine.enabled = false
AuraHighlightEngine.db = nil
AuraHighlightEngine.player_auras = {}  -- player -> { aura_id -> { name, type, duration, ... } }
AuraHighlightEngine.aura_database = {}
AuraHighlightEngine.priority_auras = {}

-- Configuration
AuraHighlightEngine.config = {
    enabled = true,
    highlight_critical_debuffs = true,
    highlight_missing_buffs = true,
    highlight_dangerous_auras = true,
    track_duration = true,
    max_auras_per_player = 32,
    update_interval = 1,
}

function AuraHighlightEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusHealer")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.aura_database then
        self.db.aura_database = self:InitializeAuraDatabase()
    end
    
    self.aura_database = self.db.aura_database
    self.enabled = true
    
    -- Register for events
    PluribusCore.Events:RegisterListener("buff_applied", function(data)
        self:OnBuffApplied(data)
    end)
    
    PluribusCore.Events:RegisterListener("buff_removed", function(data)
        self:OnBuffRemoved(data)
    end)
    
    self:Log("Initialized with " .. self:CountAuras() .. " known auras")
end

function AuraHighlightEngine:InitializeAuraDatabase()
    -- Comprehensive aura database
    return {
        -- Critical Debuffs (require immediate action)
        ["Mortal Strike"] = { type = "debuff", priority = "critical", color = "FF0000", category = "physical" },
        ["Poison"] = { type = "debuff", priority = "critical", color = "FF00FF", category = "poison" },
        ["Disease"] = { type = "debuff", priority = "critical", color = "8B4513", category = "disease" },
        ["Curse"] = { type = "debuff", priority = "high", color = "9400D3", category = "curse" },
        ["Bleed"] = { type = "debuff", priority = "high", color = "FF6347", category = "physical" },
        
        -- Tank Buffs (should always be active)
        ["Power Word: Fortitude"] = { type = "buff", priority = "tank", color = "FFD700", category = "buff" },
        ["Stamina"] = { type = "buff", priority = "tank", color = "FFD700", category = "buff" },
        ["Thorns"] = { type = "buff", priority = "tank", color = "008000", category = "buff" },
        ["Blessing of Kings"] = { type = "buff", priority = "tank", color = "FFD700", category = "buff" },
        ["Blessing of Might"] = { type = "buff", priority = "tank", color = "FFD700", category = "buff" },
        ["Mark of the Wild"] = { type = "buff", priority = "tank", color = "008000", category = "buff" },
        ["Mage Armor"] = { type = "buff", priority = "tank", color = "1E90FF", category = "buff" },
        
        -- Dangerous Auras (should be dispelled)
        ["Silence"] = { type = "debuff", priority = "critical", color = "FFFFFF", category = "magical" },
        ["Fear"] = { type = "debuff", priority = "critical", color = "000000", category = "magical" },
        ["Stun"] = { type = "debuff", priority = "critical", color = "000000", category = "magical" },
        ["Root"] = { type = "debuff", priority = "high", color = "8B0000", category = "magical" },
        
        -- Positive Buffs
        ["Power Word: Shield"] = { type = "buff", priority = "shield", color = "FFD700", category = "shield" },
        ["Divine Shield"] = { type = "buff", priority = "shield", color = "FFD700", category = "shield" },
        ["Ice Barrier"] = { type = "buff", priority = "shield", color = "00CED1", category = "shield" },
        ["Mana Shield"] = { type = "buff", priority = "shield", color = "9370DB", category = "shield" },
        
        -- HoT Status
        ["Renew"] = { type = "buff", priority = "hot", color = "90EE90", category = "heal" },
        ["Rejuvenation"] = { type = "buff", priority = "hot", color = "90EE90", category = "heal" },
        ["Lifebloom"] = { type = "buff", priority = "hot", color = "90EE90", category = "heal" },
        ["Regrowth"] = { type = "buff", priority = "hot", color = "90EE90", category = "heal" },
        ["Wild Growth"] = { type = "buff", priority = "hot", color = "90EE90", category = "heal" },
        
        -- Crowd Control
        ["Frozen"] = { type = "debuff", priority = "critical", color = "00CED1", category = "cc" },
        ["Stunned"] = { type = "debuff", priority = "critical", color = "000000", category = "cc" },
        ["Polymorphed"] = { type = "debuff", priority = "critical", color = "FFB6C1", category = "cc" },
    }
end

function AuraHighlightEngine:OnBuffApplied(data)
    if not self.enabled or not data.player or not data.buff then
        return
    end
    
    self:RegisterAura(data.player, data.buff, "buff", data.duration or 0, data.caster or "Unknown")
end

function AuraHighlightEngine:OnBuffRemoved(data)
    if not self.enabled or not data.player or not data.buff then
        return
    end
    
    self:RemoveAura(data.player, data.buff)
end

function AuraHighlightEngine:RegisterAura(playerName, auraName, auraType, duration, casterName)
    if not playerName or not auraName then
        return
    end
    
    -- Validate aura type
    auraType = auraType or "buff"
    
    if not self.player_auras[playerName] then
        self.player_auras[playerName] = {}
    end
    
    -- Check max auras
    if self:CountTable(self.player_auras[playerName]) >= self.config.max_auras_per_player then
        return
    end
    
    -- Get aura info
    local auraInfo = self.aura_database[auraName]
    
    -- Create aura record
    local auraRecord = {
        name = auraName,
        type = auraType,
        caster = casterName,
        duration = duration,
        end_time = GetTime() + duration,
        priority = auraInfo and auraInfo.priority or "normal",
        color = auraInfo and auraInfo.color or "FFFFFF",
        category = auraInfo and auraInfo.category or "unknown",
        timestamp = GetTime(),
    }
    
    self.player_auras[playerName][auraName] = auraRecord
    
    self:Log("Aura registered: " .. playerName .. " " .. auraName .. " (" .. (auraInfo and auraInfo.priority or "normal") .. ")")
end

function AuraHighlightEngine:RemoveAura(playerName, auraName)
    if not playerName or not auraName then
        return
    end
    
    if not self.player_auras[playerName] then
        return
    end
    
    if self.player_auras[playerName][auraName] then
        self.player_auras[playerName][auraName] = nil
        self:Log("Aura removed: " .. playerName .. " " .. auraName)
    end
end

function AuraHighlightEngine:GetPlayerAuras(playerName)
    if not playerName or not self.player_auras[playerName] then
        return {}
    end
    
    -- Remove expired auras
    local now = GetTime()
    for auraName, aura in pairs(self.player_auras[playerName]) do
        if aura.duration > 0 and now > aura.end_time then
            self.player_auras[playerName][auraName] = nil
        end
    end
    
    return self.player_auras[playerName]
end

function AuraHighlightEngine:GetCriticalAuras(playerName)
    if not playerName then
        return {}
    end
    
    local auras = self:GetPlayerAuras(playerName)
    local critical = {}
    
    for auraName, aura in pairs(auras) do
        if aura.priority == "critical" or aura.priority == "high" then
            table.insert(critical, {
                name = auraName,
                type = aura.type,
                priority = aura.priority,
                color = aura.color,
                remaining_time = aura.duration > 0 and math.max(0, aura.end_time - GetTime()) or 0,
            })
        end
    end
    
    -- Sort by priority
    table.sort(critical, function(a, b)
        if a.priority ~= b.priority then
            if a.priority == "critical" then return true end
            if b.priority == "critical" then return false end
        end
        return a.name < b.name
    end)
    
    return critical
end

function AuraHighlightEngine:GetMissingBuffs(playerName, expectedBuffs)
    if not playerName or not expectedBuffs or #expectedBuffs == 0 then
        return {}
    end
    
    local auras = self:GetPlayerAuras(playerName)
    local missing = {}
    
    for _, buffName in ipairs(expectedBuffs) do
        if not auras[buffName] then
            table.insert(missing, {
                name = buffName,
                priority = "missing",
                color = "FF0000",
            })
        end
    end
    
    return missing
end

function AuraHighlightEngine:GetAuraSummary(playerName)
    if not playerName then
        return nil
    end
    
    local auras = self:GetPlayerAuras(playerName)
    local summary = {
        player = playerName,
        total_auras = 0,
        buffs = 0,
        debuffs = 0,
        critical_auras = {},
        auras_by_priority = {},
    }
    
    for auraName, aura in pairs(auras) do
        summary.total_auras = summary.total_auras + 1
        
        if aura.type == "buff" then
            summary.buffs = summary.buffs + 1
        elseif aura.type == "debuff" then
            summary.debuffs = summary.debuffs + 1
        end
        
        -- Track critical auras
        if aura.priority == "critical" or aura.priority == "high" then
            table.insert(summary.critical_auras, auraName)
        end
        
        -- Track by priority
        if not summary.auras_by_priority[aura.priority] then
            summary.auras_by_priority[aura.priority] = 0
        end
        summary.auras_by_priority[aura.priority] = summary.auras_by_priority[aura.priority] + 1
    end
    
    return summary
end

function AuraHighlightEngine:IsAuraKnown(auraName)
    return self.aura_database[auraName] ~= nil
end

function AuraHighlightEngine:CountAuras()
    local count = 0
    for _ in pairs(self.aura_database) do
        count = count + 1
    end
    return count
end

function AuraHighlightEngine:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function AuraHighlightEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function AuraHighlightEngine:GetStatus()
    local tracking = 0
    for _ in pairs(self.player_auras) do
        tracking = tracking + 1
    end
    
    return {
        enabled = self.enabled,
        players_tracked = tracking,
        known_auras = self:CountAuras(),
        highlight_critical = self.config.highlight_critical_debuffs,
        highlight_missing = self.config.highlight_missing_buffs,
    }
end

function AuraHighlightEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[AuraHighlightEngine] " .. message)
    else
        print("[AuraHighlightEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_AURAHLITE1 = "/aurahlite"
    SlashCmdList["AURAHLITE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            if args and args ~= "" then
                local summary = AuraHighlightEngine:GetAuraSummary(args)
                if summary and summary.total_auras > 0 then
                    print("Auras on " .. args .. " (" .. summary.total_auras .. " total):")
                    print("  Buffs: " .. summary.buffs .. ", Debuffs: " .. summary.debuffs)
                    if #summary.critical_auras > 0 then
                        print("  ⚠️ CRITICAL: " .. table.concat(summary.critical_auras, ", "))
                    end
                else
                    print("No auras on " .. args)
                end
            else
                print("Usage: /aurahlite list <player>")
            end
        elseif cmd == "critical" then
            if args and args ~= "" then
                local critical = AuraHighlightEngine:GetCriticalAuras(args)
                if #critical > 0 then
                    print("Critical auras on " .. args .. ":")
                    for _, aura in ipairs(critical) do
                        print(string.format("  %s (%s)", aura.name, aura.priority))
                    end
                else
                    print("No critical auras on " .. args)
                end
            else
                print("Usage: /aurahlite critical <player>")
            end
        elseif cmd == "status" then
            local status = AuraHighlightEngine:GetStatus()
            print("Aura Highlight Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Aura Highlight Commands:")
            print("  /aurahlite list <player> - List auras on player")
            print("  /aurahlite critical <player> - Show critical auras")
            print("  /aurahlite status - Show system status")
        end
    end
end

return AuraHighlightEngine
