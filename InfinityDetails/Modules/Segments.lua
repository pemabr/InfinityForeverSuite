-- Segments Module
-- Encounter segments (boss pulls, trash, phases)

local InfinityDetailsSegments = {}
_G.InfinityDetailsSegments = InfinityDetailsSegments

InfinityDetailsSegments.segments = {}
InfinityDetailsSegments.current_segment = nil
InfinityDetailsSegments.callbacks = {}

function InfinityDetailsSegments:StartSegment(name, bossName)
    local segment = {
        id = #self.segments + 1,
        name = name or "Unknown",
        boss = bossName or "Unknown",
        start_time = GetTime(),
        end_time = nil,
        duration = 0,
        actors = {},
    }
    
    self.current_segment = segment
    table.insert(self.segments, segment)
    self:TriggerCallback("segment_started", segment.name)
    
    return segment
end

function InfinityDetailsSegments:EndSegment()
    if not self.current_segment then return nil end
    
    self.current_segment.end_time = GetTime()
    self.current_segment.duration = self.current_segment.end_time - self.current_segment.start_time
    
    self:TriggerCallback("segment_ended", self.current_segment.name, self.current_segment.duration)
    
    local segment = self.current_segment
    self.current_segment = nil
    return segment
end

function InfinityDetailsSegments:GetSegment(index)
    return self.segments[index]
end

function InfinityDetailsSegments:GetAllSegments()
    return self.segments
end

function InfinityDetailsSegments:GetSegmentStats(index)
    local segment = self.segments[index]
    if not segment then return nil end
    
    return {
        name = segment.name,
        boss = segment.boss,
        duration = segment.duration,
        actor_count = #segment.actors,
    }
end

function InfinityDetailsSegments:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDetailsSegments:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

function InfinityDetailsSegments:Clear()
    self.segments = {}
    self.current_segment = nil
end

return InfinityDetailsSegments
