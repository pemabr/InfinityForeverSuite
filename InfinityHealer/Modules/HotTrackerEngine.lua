-- HotTrackerEngine.lua - Track and display active HoT (Heal over Time) buffs
-- Part of InfinityHealer addon suite
-- Maintains real-time HoT tracking with tick prediction and remaining duration

local HotTrackerEngine = {}
HotTrackerEngine.enabled = false
HotTrackerEngine.db = nil
HotTrackerEngine.player_hots = {}  -- player -> { buff_id -> { spell, duration, end_time, caster, ... } }
HotTrackerEngine.hot_database = {}
HotTrackerEngine.update_frequency = 0.3  -- Update every 300ms

-- Configuration
HotTrackerEngine.config = {
    enabled = true,
    track_all_hots = true,
    show_tick_count = true,
    show_remaining_time = true,
    prediction_accuracy = true,
    update_interval = 0.3,
    max_hots_per_player = 20,
}

function HotTrackerEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityHealer")
    if not self.db then
        self.db = {}
    end
    
    -- Initialize HoT database
    if not self.db.hot_database then
        self.db.hot_database = self:InitializeHotDatabase()
    end
    
    self.hot_database = self.db.hot_database
    self.enabled = true
    
    -- Register for events
    InfinityCore.Events:RegisterListener("spell_cast", function(data)
        self:OnSpellCast(data)
    end)
    
    InfinityCore.Events:RegisterListener("buff_applied", function(data)
        self:OnBuffApplied(data)
    end)
    
    self:Log("Initialized with " .. self:CountHoTSpells() .. " HoT spells")
end

function HotTrackerEngine:InitializeHotDatabase()
    -- Comprehensive HoT database
    return {
        -- Priest
        ["Renew"] = { duration = 15, tick_time = 3, school = "holy" },
        ["Power Word: Shield"] = { duration = 15, absorption = true, school = "holy" },
        
        -- Druid
        ["Rejuvenation"] = { duration = 12, tick_time = 3, school = "nature" },
        ["Lifebloom"] = { duration = 7, tick_time = 1, school = "nature" },
        ["Regrowth"] = { duration = 21, tick_time = 3, school = "nature" },
        ["Wild Growth"] = { duration = 7, tick_time = 1, school = "nature" },
        ["Rejuvenation (Germination)"] = { duration = 12, tick_time = 3, school = "nature" },
        
        -- Paladin
        ["Beacon of Light"] = { duration = 60, reflection = true, school = "holy" },
        
        -- Shaman
        ["Healing Rain"] = { duration = 10, tick_time = 2, school = "nature" },
        ["Earthliving"] = { duration = 12, tick_time = 3, school = "nature" },
        
        -- Monk
        ["Renewing Mist"] = { duration = 20, tick_time = 2, school = "nature" },
        ["Enveloping Mist"] = { duration = 8, tick_time = 2, school = "nature" },
        
        -- Generic/Potion
        ["Greater Heal over Time"] = { duration = 10, tick_time = 2, school = "holy" },
    }
end

function HotTrackerEngine:OnSpellCast(data)
    if not self.enabled or not data.spell or not data.target then
        return
    end
    
    -- Check if spell is a HoT
    if self:IsHotSpell(data.spell) then
        self:RegisterHoT(data.target, data.spell, data.caster or UnitName("player"))
    end
end

function HotTrackerEngine:OnBuffApplied(data)
    if not self.enabled or not data.player or not data.buff then
        return
    end
    
    if self:IsHotSpell(data.buff) then
        self:RegisterHoT(data.player, data.buff, data.caster or "Unknown")
    end
end

function HotTrackerEngine:RegisterHoT(playerName, spellName, casterName)
    if not playerName or not spellName then
        return
    end
    
    -- Get HoT info
    local hotInfo = self.hot_database[spellName]
    if not hotInfo then
        self:Log("Unknown HoT spell: " .. spellName)
        return
    end
    
    if not self.player_hots[playerName] then
        self.player_hots[playerName] = {}
    end
    
    -- Check max HoTs
    if self:CountTable(self.player_hots[playerName]) >= self.config.max_hots_per_player then
        self:Log("Max HoTs reached for " .. playerName)
        return
    end
    
    -- Create HoT record
    local hotRecord = {
        spell = spellName,
        caster = casterName,
        duration = hotInfo.duration,
        end_time = GetTime() + hotInfo.duration,
        tick_time = hotInfo.tick_time,
        ticks_total = math.ceil(hotInfo.duration / hotInfo.tick_time),
        ticks_remaining = math.ceil(hotInfo.duration / hotInfo.tick_time),
        school = hotInfo.school,
        absorption = hotInfo.absorption or false,
        reflection = hotInfo.reflection or false,
        timestamp = GetTime(),
    }
    
    -- Use spell name as buff ID (simplified)
    local buffId = spellName .. "_" .. casterName
    self.player_hots[playerName][buffId] = hotRecord
    
    self:Log("HoT registered: " .. playerName .. " " .. spellName .. " from " .. casterName .. " (" .. hotRecord.ticks_total .. " ticks)")
end

function HotTrackerEngine:GetPlayerHoTs(playerName)
    if not playerName or not self.player_hots[playerName] then
        return {}
    end
    
    -- Remove expired HoTs
    local now = GetTime()
    for buffId, hot in pairs(self.player_hots[playerName]) do
        if now > hot.end_time then
            self.player_hots[playerName][buffId] = nil
        end
    end
    
    -- Return active HoTs
    return self.player_hots[playerName]
end

function HotTrackerEngine:GetHoTInfo(playerName, spellName)
    if not playerName or not spellName then
        return nil
    end
    
    local hots = self:GetPlayerHoTs(playerName)
    
    -- Search for matching HoT
    for buffId, hot in pairs(hots) do
        if hot.spell == spellName then
            -- Calculate remaining info
            local now = GetTime()
            local remaining = math.max(0, hot.end_time - now)
            
            hot.remaining_time = remaining
            hot.remaining_percent = (remaining / hot.duration) * 100
            hot.ticks_remaining = math.max(0, math.ceil(remaining / hot.tick_time))
            
            return hot
        end
    end
    
    return nil
end

function HotTrackerEngine:GetAllPlayerHoTsSummary(playerName)
    if not playerName then
        return nil
    end
    
    local hots = self:GetPlayerHoTs(playerName)
    local summary = {
        player = playerName,
        total_hots = 0,
        hots_by_caster = {},
        hots_by_school = {},
        total_ticks_remaining = 0,
        hots = {},
    }
    
    for buffId, hot in pairs(hots) do
        summary.total_hots = summary.total_hots + 1
        
        local now = GetTime()
        local remaining = math.max(0, hot.end_time - now)
        local ticks = math.max(0, math.ceil(remaining / hot.tick_time))
        
        -- Build caster summary
        if not summary.hots_by_caster[hot.caster] then
            summary.hots_by_caster[hot.caster] = 0
        end
        summary.hots_by_caster[hot.caster] = summary.hots_by_caster[hot.caster] + 1
        
        -- Build school summary
        if not summary.hots_by_school[hot.school] then
            summary.hots_by_school[hot.school] = 0
        end
        summary.hots_by_school[hot.school] = summary.hots_by_school[hot.school] + 1
        
        summary.total_ticks_remaining = summary.total_ticks_remaining + ticks
        
        -- Add to list
        table.insert(summary.hots, {
            spell = hot.spell,
            caster = hot.caster,
            remaining_time = remaining,
            remaining_percent = (remaining / hot.duration) * 100,
            ticks_remaining = ticks,
            ticks_total = hot.ticks_total,
            school = hot.school,
        })
    end
    
    return summary
end

function HotTrackerEngine:IsHotSpell(spellName)
    return self.hot_database[spellName] ~= nil
end

function HotTrackerEngine:CanStackHoT(spellName)
    -- Some HoTs can stack (like Rejuvenation), others can't (like Lifebloom)
    local stackable = {
        ["Renew"] = true,
        ["Rejuvenation"] = true,
        ["Healing Rain"] = true,
        ["Renewing Mist"] = true,
    }
    
    return stackable[spellName] or false
end

function HotTrackerEngine:CountHoTSpells()
    local count = 0
    for _ in pairs(self.hot_database) do
        count = count + 1
    end
    return count
end

function HotTrackerEngine:CountTable(t)
    local count = 0
    for _ in pairs(t or {}) do
        count = count + 1
    end
    return count
end

function HotTrackerEngine:SetConfig(key, value)
    if self.config[key] ~= nil then
        self.config[key] = value
        self:Log("Config updated: " .. key .. " = " .. tostring(value))
        return true
    end
    return false
end

function HotTrackerEngine:GetStatus()
    local totalTracking = 0
    for _ in pairs(self.player_hots) do
        totalTracking = totalTracking + 1
    end
    
    return {
        enabled = self.enabled,
        players_tracked = totalTracking,
        hot_spells_known = self:CountHoTSpells(),
        total_active_hots = self:CountTable(self.player_hots),
    }
end

function HotTrackerEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[HotTrackerEngine] " .. message)
    else
        print("[HotTrackerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_HOTTRACK1 = "/hottrack"
    SlashCmdList["HOTTRACK"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "list" then
            if args and args ~= "" then
                local summary = HotTrackerEngine:GetAllPlayerHoTsSummary(args)
                if summary and summary.total_hots > 0 then
                    print("HoTs on " .. args .. " (" .. summary.total_hots .. " total):")
                    for _, hot in ipairs(summary.hots) do
                        print(string.format("  %s (from %s): %.1fs left (%d ticks)", 
                            hot.spell, hot.caster, hot.remaining_time, hot.ticks_remaining))
                    end
                else
                    print("No HoTs on " .. args)
                end
            else
                print("Usage: /hottrack list <player>")
            end
        elseif cmd == "status" then
            local status = HotTrackerEngine:GetStatus()
            print("HoT Tracker Status:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "spells" then
            print("Known HoT spells (" .. HotTrackerEngine:CountHoTSpells() .. "):")
            local count = 0
            for spell, _ in pairs(HotTrackerEngine.hot_database) do
                count = count + 1
                if count <= 15 then
                    print("  " .. spell)
                end
            end
            if HotTrackerEngine:CountHoTSpells() > 15 then
                print("  ... and " .. (HotTrackerEngine:CountHoTSpells() - 15) .. " more")
            end
        else
            print("HoT Tracker Commands:")
            print("  /hottrack list <player> - Show HoTs on player")
            print("  /hottrack status - Show system status")
            print("  /hottrack spells - List known HoT spells")
        end
    end
end

return HotTrackerEngine
