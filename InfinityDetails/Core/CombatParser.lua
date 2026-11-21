-- Combat Parser
-- Parse COMBAT_LOG_EVENT_UNFILTERED for damage, healing, threat

local InfinityDetailsCombatParser = {}
_G.InfinityDetailsCombatParser = InfinityDetailsCombatParser

InfinityDetailsCombatParser.events = {}
InfinityDetailsCombatParser.callbacks = {}
InfinityDetailsCombatParser.parsing = false
InfinityDetailsCombatParser.start_time = nil

function InfinityDetailsCombatParser:StartParsing()
    self.parsing = true
    self.start_time = GetTime()
    self.events = {}
    self:TriggerCallback("parse_started")
end

function InfinityDetailsCombatParser:StopParsing()
    self.parsing = false
    self:TriggerCallback("parse_stopped")
end

function InfinityDetailsCombatParser:IsParsing()
    return self.parsing
end

function InfinityDetailsCombatParser:OnCombatLogEvent(...)
    if not self.parsing then return end
    
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellID, spellName, spellSchool,
          amount, overkill = ...
    
    -- Create event record
    local event = {
        timestamp = timestamp,
        time = GetTime() - self.start_time,
        subevent = subevent,
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        sourceFlags = sourceFlags,
        destGUID = destGUID,
        destName = destName,
        destFlags = destFlags,
        spellID = spellID,
        spellName = spellName,
        spellSchool = spellSchool,
        amount = amount or 0,
        overkill = overkill or 0,
    }
    
    table.insert(self.events, event)
    
    -- Route to appropriate handler based on subevent
    if subevent:find("DAMAGE") then
        self:TriggerCallback("damage_event", event)
    elseif subevent:find("HEAL") then
        self:TriggerCallback("heal_event", event)
    elseif subevent:find("THREAT") then
        self:TriggerCallback("threat_event", event)
    elseif subevent:find("DIED") then
        self:TriggerCallback("death_event", event)
    end
end

function InfinityDetailsCombatParser:GetEventCount()
    return #self.events
end

function InfinityDetailsCombatParser:GetEvents(limit)
    limit = limit or 100
    local result = {}
    
    for i = math.max(1, #self.events - limit + 1), #self.events do
        table.insert(result, self.events[i])
    end
    
    return result
end

function InfinityDetailsCombatParser:FilterEvents(subevent)
    local result = {}
    
    for _, event in ipairs(self.events) do
        if event.subevent == subevent or string.find(event.subevent, subevent) then
            table.insert(result, event)
        end
    end
    
    return result
end

function InfinityDetailsCombatParser:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDetailsCombatParser:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityDetailsCombatParser:Clear()
    self.events = {}
    self.parsing = false
end

return InfinityDetailsCombatParser
