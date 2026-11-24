-- SegmentManagementEngine.lua - Manage combat segments and boss phases
-- Part of PluribusDetails addon suite
-- Tracks encounter segments, boss phases, deaths, and scene changes

local SegmentManagementEngine = {}
SegmentManagementEngine.enabled = false
SegmentManagementEngine.db = nil
SegmentManagementEngine.segments = {}
SegmentManagementEngine.current_segment = nil
SegmentManagementEngine.phase_data = {}

-- Configuration
SegmentManagementEngine.config = {
    enabled = true,
    auto_segment = true,
    max_segments = 100,
}

-- Segment types
SegmentManagementEngine.segment_types = {
    TRASH = "trash",
    BOSS = "boss",
    DUNGEON = "dungeon",
    WORLD = "world",
    ARENA = "arena",
}

-- Boss phase types
SegmentManagementEngine.phase_types = {
    NORMAL = "normal",
    HEROIC = "heroic",
    PHASE_CHANGE = "phase_change",
    BURN_PHASE = "burn_phase",
}

function SegmentManagementEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.segments then
        self.db.segments = {
            encounters = {},
            current_segment_id = 0,
        }
    end
    
    self.segments = self.db.segments.encounters
    self.enabled = true
    
    self:Log("Initialized segment manager with auto-segment: " .. tostring(self.config.auto_segment))
end

function SegmentManagementEngine:StartSegment(segmentName, segmentType, bossId, difficulty)
    if not segmentName or not segmentType then
        return false
    end
    
    -- Create new segment
    local segment = {
        id = self:GetNextSegmentId(),
        name = segmentName,
        type = segmentType,
        boss_id = bossId,
        difficulty = difficulty or "normal",
        start_time = GetTime(),
        end_time = nil,
        duration = 0,
        status = "active",
        phases = {},
        current_phase = nil,
        deaths = {},
        events_start = 0,
        events_end = 0,
    }
    
    -- Set as current segment
    self.current_segment = segment
    
    -- Add to segments
    table.insert(self.segments, segment)
    
    -- Trim old segments if too many
    if #self.segments > self.config.max_segments then
        table.remove(self.segments, 1)
    end
    
    self:Log("Started segment: " .. segmentName .. " (" .. segmentType .. ")")
    
    return segment
end

function SegmentManagementEngine:EndSegment(endStatus)
    if not self.current_segment then
        return false
    end
    
    local segment = self.current_segment
    segment.end_time = GetTime()
    segment.duration = segment.end_time - segment.start_time
    segment.status = endStatus or "complete"
    
    self:Log("Ended segment: " .. segment.name .. " (Duration: " .. string.format("%.1f", segment.duration) .. "s, Status: " .. segment.status .. ")")
    
    self.current_segment = nil
    
    return segment
end

function SegmentManagementEngine:AddPhase(phaseName, phaseType, bossPrimaryTarget)
    if not self.current_segment or not phaseName or not phaseType then
        return false
    end
    
    local phase = {
        id = self:GetNextPhaseId(),
        name = phaseName,
        type = phaseType,
        start_time = GetTime(),
        end_time = nil,
        duration = 0,
        boss_target = bossPrimaryTarget,
        health_percent = 100,
        events = {},
    }
    
    table.insert(self.current_segment.phases, phase)
    self.current_segment.current_phase = phase
    
    self:Log("Phase started: " .. phaseName .. " (" .. phaseType .. ")")
    
    return phase
end

function SegmentManagementEngine:EndPhase()
    if not self.current_segment or not self.current_segment.current_phase then
        return false
    end
    
    local phase = self.current_segment.current_phase
    phase.end_time = GetTime()
    phase.duration = phase.end_time - phase.start_time
    
    self:Log("Phase ended: " .. phase.name .. " (Duration: " .. string.format("%.1f", phase.duration) .. "s)")
    
    self.current_segment.current_phase = nil
    
    return phase
end

function SegmentManagementEngine:RecordDeath(playerGUID, playerName, deathTime, killedBy)
    if not self.current_segment or not playerGUID then
        return false
    end
    
    local death = {
        player_guid = playerGUID,
        player_name = playerName,
        time = deathTime or GetTime(),
        killed_by = killedBy,
        phase = self.current_segment.current_phase and self.current_segment.current_phase.name or "unknown",
    }
    
    table.insert(self.current_segment.deaths, death)
    
    self:Log("Death recorded: " .. playerName .. " (Phase: " .. death.phase .. ")")
    
    return death
end

function SegmentManagementEngine:SetPhaseHealth(healthPercent)
    if not self.current_segment or not self.current_segment.current_phase then
        return false
    end
    
    self.current_segment.current_phase.health_percent = healthPercent
    
    return true
end

function SegmentManagementEngine:GetCurrentSegment()
    return self.current_segment
end

function SegmentManagementEngine:GetSegmentById(segmentId)
    if not segmentId then
        return nil
    end
    
    for _, segment in ipairs(self.segments) do
        if segment.id == segmentId then
            return segment
        end
    end
    
    return nil
end

function SegmentManagementEngine:GetSegmentsByBoss(bossId)
    if not bossId then
        return {}
    end
    
    local results = {}
    
    for _, segment in ipairs(self.segments) do
        if segment.boss_id == bossId then
            table.insert(results, segment)
        end
    end
    
    return results
end

function SegmentManagementEngine:GetSegmentsByType(segmentType)
    if not segmentType then
        return {}
    end
    
    local results = {}
    
    for _, segment in ipairs(self.segments) do
        if segment.type == segmentType then
            table.insert(results, segment)
        end
    end
    
    return results
end

function SegmentManagementEngine:GetAllSegments()
    return self.segments
end

function SegmentManagementEngine:GetSegmentDeaths(segmentId)
    local segment = self:GetSegmentById(segmentId)
    
    if not segment then
        return {}
    end
    
    return segment.deaths
end

function SegmentManagementEngine:GetDeathsByPlayer(playerGUID)
    if not playerGUID then
        return {}
    end
    
    local deaths = {}
    
    for _, segment in ipairs(self.segments) do
        for _, death in ipairs(segment.deaths) do
            if death.player_guid == playerGUID then
                table.insert(deaths, death)
            end
        end
    end
    
    return deaths
end

function SegmentManagementEngine:GetPhaseCount(segmentId)
    local segment = self:GetSegmentById(segmentId)
    
    if not segment then
        return 0
    end
    
    return #segment.phases
end

function SegmentManagementEngine:GetPhaseByName(segmentId, phaseName)
    local segment = self:GetSegmentById(segmentId)
    
    if not segment then
        return nil
    end
    
    for _, phase in ipairs(segment.phases) do
        if phase.name == phaseName then
            return phase
        end
    end
    
    return nil
end

function SegmentManagementEngine:GetNextSegmentId()
    local maxId = 0
    
    for _, segment in ipairs(self.segments) do
        if segment.id and segment.id > maxId then
            maxId = segment.id
        end
    end
    
    return maxId + 1
end

function SegmentManagementEngine:GetNextPhaseId()
    if not self.current_segment then
        return 1
    end
    
    local maxId = 0
    
    for _, phase in ipairs(self.current_segment.phases) do
        if phase.id and phase.id > maxId then
            maxId = phase.id
        end
    end
    
    return maxId + 1
end

function SegmentManagementEngine:GetSegmentStats(segmentId)
    local segment = self:GetSegmentById(segmentId)
    
    if not segment then
        return nil
    end
    
    return {
        name = segment.name,
        type = segment.type,
        difficulty = segment.difficulty,
        duration = segment.duration,
        status = segment.status,
        phase_count = #segment.phases,
        death_count = #segment.deaths,
        start_time = segment.start_time,
        end_time = segment.end_time,
    }
end

function SegmentManagementEngine:ClearData()
    self.segments = {}
    self.current_segment = nil
    self.phase_data = {}
    self:Log("All segment data cleared")
end

function SegmentManagementEngine:GetStatus()
    local hasActive = self.current_segment ~= nil
    
    return {
        enabled = self.enabled,
        active_segment = hasActive and self.current_segment.name or "None",
        segment_count = #self.segments,
        max_segments = self.config.max_segments,
        auto_segment = self.config.auto_segment,
    }
end

function SegmentManagementEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[SegmentManagementEngine] " .. message)
    else
        print("[SegmentManagementEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_SEGMENT1 = "/segment"
    SlashCmdList["SEGMENT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "start" then
            if args and args ~= "" then
                SegmentManagementEngine:StartSegment(args, SegmentManagementEngine.segment_types.BOSS)
                print("Segment started: " .. args)
            else
                print("Usage: /segment start <name>")
            end
        elseif cmd == "end" then
            local segment = SegmentManagementEngine:EndSegment("complete")
            if segment then
                print("Segment ended: " .. segment.name)
            end
        elseif cmd == "phase" then
            if args and args ~= "" then
                SegmentManagementEngine:AddPhase(args, SegmentManagementEngine.phase_types.NORMAL)
                print("Phase started: " .. args)
            else
                print("Usage: /segment phase <name>")
            end
        elseif cmd == "death" then
            if args and args ~= "" then
                SegmentManagementEngine:RecordDeath(nil, args)
                print("Death recorded: " .. args)
            else
                print("Usage: /segment death <player>")
            end
        elseif cmd == "list" then
            local segments = SegmentManagementEngine:GetAllSegments()
            print("Segments (" .. #segments .. "):")
            for i, segment in ipairs(segments) do
                print(string.format("  %d. %s (%s) - %.1fs", i, segment.name, segment.type, segment.duration))
            end
        elseif cmd == "status" then
            local status = SegmentManagementEngine:GetStatus()
            print("Segment Manager:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Segment Manager Commands:")
            print("  /segment start <name> - Start a new segment")
            print("  /segment end - End current segment")
            print("  /segment phase <name> - Start a new phase")
            print("  /segment death <player> - Record a death")
            print("  /segment list - List all segments")
            print("  /segment status - Show system status")
        end
    end
end

return SegmentManagementEngine
