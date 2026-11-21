-- CombatLogParserEngine.lua - Real-time WoW combat log parsing
-- Part of InfinityDetails addon suite
-- Parses combat events and feeds data to analytics engines

local CombatLogParserEngine = {}
CombatLogParserEngine.enabled = false
CombatLogParserEngine.db = nil
CombatLogParserEngine.event_buffer = {}
CombatLogParserEngine.event_callbacks = {}
CombatLogParserEngine.last_combat_time = 0

-- Event buffer configuration
CombatLogParserEngine.config = {
    enabled = true,
    buffer_size = 1000,
    parse_frequency = 0.1,  -- Every 100ms
    max_events_per_parse = 100,
}

-- Combat event types
CombatLogParserEngine.event_types = {
    DAMAGE = "DAMAGE",
    HEAL = "HEAL",
    ABSORB = "ABSORB",
    DEATH = "DEATH",
    CAST_START = "CAST_START",
    CAST_SUCCESS = "CAST_SUCCESS",
    CAST_FAILED = "CAST_FAILED",
    RESOURCE = "RESOURCE",
    THREAT = "THREAT",
    BUFF = "BUFF",
    DEBUFF = "DEBUFF",
}

function CombatLogParserEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.combat_data then
        self.db.combat_data = {
            actors = {},
            events = {},
            segments = {},
            current_segment = nil,
        }
    end
    
    if not self.db.parser_config then
        self.db.parser_config = {
            start_time = 0,
            end_time = 0,
            total_events = 0,
            last_parse = 0,
        }
    end
    
    self.enabled = true
    self:Log("Initialized with event buffer size: " .. self.config.buffer_size)
    
    -- Start event parsing timer
    self:StartParsing()
end

function CombatLogParserEngine:RegisterEventCallback(eventType, callback)
    if not eventType or not callback then
        return false
    end
    
    if not self.event_callbacks[eventType] then
        self.event_callbacks[eventType] = {}
    end
    
    table.insert(self.event_callbacks[eventType], callback)
    return true
end

function CombatLogParserEngine:StartParsing()
    if not self.enabled then
        return
    end
    
    if InfinityCore and InfinityCore.Events then
        InfinityCore.Events:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", function(...)
            CombatLogParserEngine:OnCombatEvent(...)
        end)
    end
    
    self:Log("Combat parsing started")
end

function CombatLogParserEngine:OnCombatEvent(...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags = select(1, ...)
    
    if not timestamp or not subevent then
        return
    end
    
    -- Create event structure
    local event = {
        timestamp = timestamp,
        time = GetTime(),
        type = subevent,
        source_guid = sourceGUID,
        source_name = sourceName,
        source_flags = sourceFlags,
        dest_guid = destGUID,
        dest_name = destName,
        dest_flags = destFlags,
    }
    
    -- Parse event data based on type
    if subevent == "SPELL_DAMAGE" then
        self:ParseSpellDamage(event, select(13, ...))
        event.event_type = self.event_types.DAMAGE
    elseif subevent == "SPELL_HEAL" then
        self:ParseSpellHeal(event, select(13, ...))
        event.event_type = self.event_types.HEAL
    elseif subevent == "SPELL_ABSORBED" then
        self:ParseAbsorb(event, select(13, ...))
        event.event_type = self.event_types.ABSORB
    elseif subevent == "UNIT_DIED" then
        self:ParseDeath(event)
        event.event_type = self.event_types.DEATH
    elseif subevent:match("CAST_START") then
        self:ParseCastStart(event)
        event.event_type = self.event_types.CAST_START
    elseif subevent:match("CAST_SUCCESS") then
        self:ParseCastSuccess(event)
        event.event_type = self.event_types.CAST_SUCCESS
    elseif subevent:match("CAST_FAILED") then
        self:ParseCastFailed(event)
        event.event_type = self.event_types.CAST_FAILED
    end
    
    -- Add to buffer
    table.insert(self.event_buffer, event)
    
    -- Trim buffer if too large
    if #self.event_buffer > self.config.buffer_size then
        table.remove(self.event_buffer, 1)
    end
    
    -- Update combat time
    self.last_combat_time = GetTime()
end

function CombatLogParserEngine:ParseSpellDamage(event, spellId, spellName, spellSchool, damage, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing)
    event.spell_id = spellId
    event.spell_name = spellName
    event.damage = damage or 0
    event.overkill = overkill or 0
    event.school = spellSchool
    event.resisted = resisted or 0
    event.blocked = blocked or 0
    event.absorbed = absorbed or 0
    event.critical = critical or false
end

function CombatLogParserEngine:ParseSpellHeal(event, spellId, spellName, spellSchool, heal, overheal, absorbed, critical)
    event.spell_id = spellId
    event.spell_name = spellName
    event.heal = heal or 0
    event.overheal = overheal or 0
    event.absorbed = absorbed or 0
    event.critical = critical or false
end

function CombatLogParserEngine:ParseAbsorb(event, spellId, spellName, spellSchool, casterGUID, casterName, casterFlags, casterRaidFlags, absorbAmount)
    event.spell_id = spellId
    event.spell_name = spellName
    event.caster_guid = casterGUID
    event.caster_name = casterName
    event.absorb_amount = absorbAmount or 0
end

function CombatLogParserEngine:ParseDeath(event)
    event.death_time = GetTime()
end

function CombatLogParserEngine:ParseCastStart(event, spellId, spellName, spellSchool, castGUID, startTime, endTime, isTradeSkill, castFailed, castFailReason)
    event.spell_id = spellId
    event.spell_name = spellName
    event.cast_start = startTime
    event.cast_end = endTime
    event.cast_guid = castGUID
end

function CombatLogParserEngine:ParseCastSuccess(event, spellId, spellName, spellSchool)
    event.spell_id = spellId
    event.spell_name = spellName
end

function CombatLogParserEngine:ParseCastFailed(event, spellId, spellName, spellSchool, failedType)
    event.spell_id = spellId
    event.spell_name = spellName
    event.fail_type = failedType
end

function CombatLogParserEngine:GetBufferedEvents()
    return self.event_buffer
end

function CombatLogParserEngine:GetEventsSinceTime(minTime)
    if not minTime or minTime <= 0 then
        return self.event_buffer
    end
    
    local events = {}
    for _, event in ipairs(self.event_buffer) do
        if event.time and event.time >= minTime then
            table.insert(events, event)
        end
    end
    
    return events
end

function CombatLogParserEngine:ClearBuffer()
    self.event_buffer = {}
    self:Log("Event buffer cleared")
end

function CombatLogParserEngine:GetBufferStats()
    return {
        buffer_size = #self.event_buffer,
        max_size = self.config.buffer_size,
        fill_percent = math.floor((#self.event_buffer / self.config.buffer_size) * 100),
        last_event_time = self.last_combat_time,
        time_since_last_event = GetTime() - self.last_combat_time,
    }
end

function CombatLogParserEngine:IsInCombat()
    return (GetTime() - self.last_combat_time) < 5  -- Within 5 seconds of last event
end

function CombatLogParserEngine:SetBufferSize(size)
    if size and size > 100 and size <= 5000 then
        self.config.buffer_size = size
        self:Log("Buffer size set to: " .. size)
        return true
    end
    return false
end

function CombatLogParserEngine:GetEventTypeStats()
    local stats = {}
    
    for _, event in ipairs(self.event_buffer) do
        if event.event_type then
            if not stats[event.event_type] then
                stats[event.event_type] = 0
            end
            stats[event.event_type] = stats[event.event_type] + 1
        end
    end
    
    return stats
end

function CombatLogParserEngine:GetStatus()
    local bufferStats = self:GetBufferStats()
    local eventTypeStats = self:GetEventTypeStats()
    
    return {
        enabled = self.enabled,
        in_combat = self:IsInCombat(),
        buffer_size = bufferStats.buffer_size,
        max_buffer = bufferStats.max_size,
        fill_percent = bufferStats.fill_percent,
        event_types = eventTypeStats,
        callbacks_registered = self:CountCallbacks(),
    }
end

function CombatLogParserEngine:CountCallbacks()
    local count = 0
    for _ in pairs(self.event_callbacks) do
        count = count + 1
    end
    return count
end

function CombatLogParserEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[CombatLogParserEngine] " .. message)
    else
        print("[CombatLogParserEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_COMBATPARSE1 = "/combatparse"
    SlashCmdList["COMBATPARSE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "buffer" then
            local stats = CombatLogParserEngine:GetBufferStats()
            print("Combat Log Buffer:")
            for k, v in pairs(stats) do
                print("  " .. k .. ": " .. tostring(v))
            end
        elseif cmd == "events" then
            local stats = CombatLogParserEngine:GetEventTypeStats()
            print("Events by Type:")
            for type, count in pairs(stats) do
                print("  " .. type .. ": " .. count)
            end
        elseif cmd == "setsize" then
            if args and tonumber(args) then
                CombatLogParserEngine:SetBufferSize(tonumber(args))
                print("Buffer size: " .. args)
            else
                print("Usage: /combatparse setsize <size>")
            end
        elseif cmd == "clear" then
            CombatLogParserEngine:ClearBuffer()
            print("Buffer cleared")
        elseif cmd == "status" then
            local status = CombatLogParserEngine:GetStatus()
            print("Combat Parser:")
            for k, v in pairs(status) do
                if type(v) == "table" then
                    print("  " .. k .. ":")
                    for k2, v2 in pairs(v) do
                        print("    " .. k2 .. ": " .. tostring(v2))
                    end
                else
                    print("  " .. k .. ": " .. tostring(v))
                end
            end
        else
            print("Combat Parser Commands:")
            print("  /combatparse buffer - Show buffer stats")
            print("  /combatparse events - Show event counts by type")
            print("  /combatparse setsize <size> - Set buffer size")
            print("  /combatparse clear - Clear event buffer")
            print("  /combatparse status - Show system status")
        end
    end
end

return CombatLogParserEngine
