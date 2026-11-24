-- Combat Parser
-- Parse COMBAT_LOG_EVENT_UNFILTERED for damage, healing, threat

local PluribusDetailsCombatParser = {}
_G.PluribusDetailsCombatParser = PluribusDetailsCombatParser

PluribusDetailsCombatParser.events = {}
PluribusDetailsCombatParser.callbacks = {}
PluribusDetailsCombatParser.parsing = false
PluribusDetailsCombatParser.start_time = nil

function PluribusDetailsCombatParser:StartParsing()
    self.parsing = true
    self.start_time = GetTime()
    self.events = {}
    self:TriggerCallback("parse_started")
end

function PluribusDetailsCombatParser:StopParsing()
    self.parsing = false
    self:TriggerCallback("parse_stopped")
end

function PluribusDetailsCombatParser:IsParsing()
    return self.parsing
end

function PluribusDetailsCombatParser:OnCombatLogEvent(...)
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

function PluribusDetailsCombatParser:GetEventCount()
    return #self.events
end

function PluribusDetailsCombatParser:GetEvents(limit)
    limit = limit or 100
    local result = {}
    
    for i = math.max(1, #self.events - limit + 1), #self.events do
        table.insert(result, self.events[i])
    end
    
    return result
end

function PluribusDetailsCombatParser:FilterEvents(subevent)
    local result = {}
    
    for _, event in ipairs(self.events) do
        if event.subevent == subevent or string.find(event.subevent, subevent) then
            table.insert(result, event)
        end
    end
    
    return result
end

function PluribusDetailsCombatParser:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDetailsCombatParser:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function PluribusDetailsCombatParser:Clear()
    self.events = {}
    self.parsing = false
end

return PluribusDetailsCombatParser
