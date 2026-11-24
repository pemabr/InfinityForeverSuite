-- Raid Buff Tracker
-- Monitors and reports on raid buff coverage and missing buffs

local MODULE_NAME = "RaidBuffTracker"
local InfinityCore = InfinityCore or {}
local InfinityPerformanceAnalytics = InfinityPerformanceAnalytics or {}

InfinityPerformanceAnalytics.BuffTracker = {
    enabled = false,
    tracking = false,
    
    db = {
        buffs = {},
        player_buffs = {},
        buff_history = {}
    },
    
    -- Common raid buffs
    buff_whitelist = {
        -- Paladin buffs
        "Blessing of Kings",
        "Blessing of Might",
        "Blessing of Wisdom",
        "Greater Blessing of Kings",
        "Greater Blessing of Might",
        "Greater Blessing of Wisdom",
        
        -- Priest buffs
        "Power Word: Fortitude",
        "Divine Spirit",
        "Shadow Protection",
        
        -- Druid buffs
        "Mark of the Wild",
        "Gift of the Wild",
        "Thorns",
        
        -- Shaman buffs
        "Totem of Wrath",
        "Mana Spring Totem",
        "Healing Stream Totem",
        
        -- Warrior buffs
        "Battle Shout",
        "Demoralizing Shout",
        
        -- World buffs
        "Zul'Farrak Blessing",
        "Rend",
        "World Buff",
        
        -- Consumables
        "Flask of Distilled Wisdom",
        "Flask of Chromatic Resistance",
        "Flask of Supreme Power",
        "Flask of Petrification"
    },
    
    config = {
        track_important_buffs = true,
        warn_missing_buffs = true,
        refresh_rate = 5.0,
        min_raid_size = 10
    }
}

local BuffTracker = InfinityPerformanceAnalytics.BuffTracker

function BuffTracker:Initialize()
    self:ResetTracking()
end

function BuffTracker:ResetTracking()
    self.db.buffs = {}
    self.db.player_buffs = {}
    self.db.buff_history = {}
end

function BuffTracker:ScanRaidBuffs()
    if not IsInRaid() then
        return
    end
    
    self.db.player_buffs = {}
    
    local raid_size = GetNumGroupMembers()
    
    for i = 1, raid_size do
        local unit = "raid" .. i
        if UnitExists(unit) then
            self:ScanPlayerBuffs(unit)
        end
    end
end

function BuffTracker:ScanPlayerBuffs(unit)
    local unit_name = UnitName(unit)
    
    if not self.db.player_buffs[unit_name] then
        self.db.player_buffs[unit_name] = {
            name = unit_name,
            buffs = {},
            debuffs = {},
            important_missing = {}
        }
    end
    
    local player = self.db.player_buffs[unit_name]
    
    -- Scan buffs
    local buff_index = 1
    while true do
        local buff_name, buff_icon, buff_count, buff_type, buff_duration, buff_expiration = InfinityUtils:GetUnitAura(unit, buff_index, "HELPFUL")
        
        if not buff_name then
            break
        end
        
        if self:IsImportantBuff(buff_name) then
            table.insert(player.buffs, {
                name = buff_name,
                count = buff_count or 1,
                duration = buff_duration or 0,
                expiration = buff_expiration or 0,
                icon = buff_icon
            })
        end
        
        buff_index = buff_index + 1
    end
    
    -- Scan debuffs
    local debuff_index = 1
    while true do
        local debuff_name, debuff_icon, debuff_count, debuff_type = InfinityUtils:GetUnitAura(unit, debuff_index, "HARMFUL")
        
        if not debuff_name then
            break
        end
        
        if self:IsImportantDebuff(debuff_name) then
            table.insert(player.debuffs, {
                name = debuff_name,
                count = debuff_count or 1,
                type = debuff_type,
                icon = debuff_icon
            })
        end
        
        debuff_index = debuff_index + 1
    end
    
    -- Check for missing important buffs
    self:CheckMissingBuffs(player)
end

function BuffTracker:IsImportantBuff(buff_name)
    for _, whitelisted_buff in ipairs(self.buff_whitelist) do
        if string.find(buff_name, whitelisted_buff) then
            return true
        end
    end
    return false
end

function BuffTracker:IsImportantDebuff(debuff_name)
    -- Common debuffs to track
    local important_debuffs = {
        "Curse of Shadow",
        "Curse of Tongues",
        "Curse of the Elements",
        "Poison",
        "Disease",
        "Faerie Fire",
        "Winter's Chill"
    }
    
    for _, important_debuff in ipairs(important_debuffs) do
        if string.find(debuff_name, important_debuff) then
            return true
        end
    end
    
    return false
end

function BuffTracker:CheckMissingBuffs(player)
    -- Check for typical raid buffs player should have
    local expected_buffs = {
        "Kings", -- Blessing of Kings / Greater Blessing of Kings
        "Might", -- Blessing of Might / Greater Blessing of Might
        "Fortitude", -- Power Word: Fortitude
        "Wild" -- Mark of the Wild / Gift of the Wild
    }
    
    player.important_missing = {}
    
    for _, expected_buff in ipairs(expected_buffs) do
        local has_buff = false
        
        for _, actual_buff in ipairs(player.buffs) do
            if string.find(actual_buff.name, expected_buff) then
                has_buff = true
                break
            end
        end
        
        if not has_buff then
            table.insert(player.important_missing, expected_buff)
        end
    end
end

function BuffTracker:GetBuffCoverage(buff_name)
    local coverage = 0
    local total_players = 0
    
    for player_name, player_data in pairs(self.db.player_buffs) do
        total_players = total_players + 1
        
        for _, buff in ipairs(player_data.buffs) do
            if string.find(buff.name, buff_name) then
                coverage = coverage + 1
                break
            end
        end
    end
    
    if total_players == 0 then
        return 0
    end
    
    return (coverage / total_players) * 100
end

function BuffTracker:PrintBuffReport()
    print("|cff00ccffRaid Buff Coverage Report|r")
    print(string.rep("-", 60))
    
    self:ScanRaidBuffs()
    
    -- Report on buff coverage
    local important_buffs = {
        "Kings",
        "Might",
        "Fortitude",
        "Wild"
    }
    
    for _, buff_name in ipairs(important_buffs) do
        local coverage = self:GetBuffCoverage(buff_name)
        
        local color = "|cff00ff00" -- Green
        if coverage < 100 then
            color = "|cffff9900" -- Orange
        end
        if coverage < 50 then
            color = "|cffff0000" -- Red
        end
        
        print(string.format(
            "%s%s: %.1f%% coverage (%d/%d)|r",
            color,
            buff_name,
            coverage,
            math.floor(GetNumGroupMembers() * coverage / 100),
            GetNumGroupMembers()
        ))
    end
    
    print(string.rep("-", 60))
end

function BuffTracker:PrintPlayerBuffs(player_name)
    print("|cff00ccffPlayer Buff Status: " .. player_name .. "|r")
    print(string.rep("-", 60))
    
    self:ScanRaidBuffs()
    
    if not self.db.player_buffs[player_name] then
        print("Player not found in raid.")
        return
    end
    
    local player = self.db.player_buffs[player_name]
    
    if #player.buffs > 0 then
        print("|cff00ff00Active Buffs:|r")
        for _, buff in ipairs(player.buffs) do
            print(string.format("  - %s (x%d)", buff.name, buff.count))
        end
    end
    
    if #player.debuffs > 0 then
        print("|cffff0000Active Debuffs:|r")
        for _, debuff in ipairs(player.debuffs) do
            print(string.format("  - %s (x%d)", debuff.name, debuff.count))
        end
    end
    
    if #player.important_missing > 0 then
        print("|cffff9900Missing Important Buffs:|r")
        for _, missing in ipairs(player.important_missing) do
            print(string.format("  - %s", missing))
        end
    else
        print("|cff00ff00✓ All important buffs present|r")
    end
    
    print(string.rep("-", 60))
end

function BuffTracker:PrintPlayersWithoutBuff(buff_name)
    print("|cff00ccffPlayers Without " .. buff_name .. "|r")
    print(string.rep("-", 60))
    
    self:ScanRaidBuffs()
    
    local missing_count = 0
    
    for player_name, player_data in pairs(self.db.player_buffs) do
        local has_buff = false
        
        for _, buff in ipairs(player_data.buffs) do
            if string.find(buff.name, buff_name) then
                has_buff = true
                break
            end
        end
        
        if not has_buff then
            print("  - " .. player_name)
            missing_count = missing_count + 1
        end
    end
    
    if missing_count == 0 then
        print("|cff00ff00✓ All players have " .. buff_name .. "|r")
    else
        print(string.format("|cffff0000%d players missing %s|r", missing_count, buff_name))
    end
    
    print(string.rep("-", 60))
end

-- Register slash commands
if InfinityCore.SlashCommand then
    InfinityCore.SlashCommand:Register("buffs", function(args)
        if args == "report" then
            BuffTracker:PrintBuffReport()
        elseif string.find(args, "player") then
            local player = string.match(args, "player (.+)")
            if player then
                BuffTracker:PrintPlayerBuffs(player)
            end
        elseif args ~= "" then
            BuffTracker:PrintPlayersWithoutBuff(args)
        else
            BuffTracker:PrintBuffReport()
        end
    end, "Show raid buff coverage reports")
end

return InfinityPerformanceAnalytics.BuffTracker

