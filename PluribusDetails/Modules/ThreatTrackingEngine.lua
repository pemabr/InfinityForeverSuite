-- ThreatTrackingEngine.lua - Track and analyze threat data
-- Part of PluribusDetails addon suite
-- Provides real-time threat information and threat timeline

local ThreatTrackingEngine = {}
ThreatTrackingEngine.enabled = false
ThreatTrackingEngine.db = nil
ThreatTrackingEngine.threat_data = {}

-- Configuration
ThreatTrackingEngine.config = {
    enabled = true,
    track_frequency = 1,  -- Track every 1 second
    max_snapshots = 1000,  -- Max threat snapshots per actor
}

function ThreatTrackingEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.threat_tracking then
        self.db.threat_tracking = {
            actors = {},
            timeline = {},
        }
    end
    
    self.threat_data = self.db.threat_tracking
    self.enabled = true
    
    self:Log("Initialized threat tracker")
end

function ThreatTrackingEngine:RecordThreat(actorGUID, actorName, targetGUID, targetName, threatValue, threatPercent)
    if not actorGUID or not threatValue then
        return false
    end
    
    -- Create actor entry if not exists
    if not self.threat_data.actors[actorGUID] then
        self.threat_data.actors[actorGUID] = {
            name = actorName,
            guid = actorGUID,
            current_target = nil,
            current_threat = 0,
            threat_history = {},
            has_aggro = false,
            times_lost_aggro = 0,
        }
    end
    
    local actorData = self.threat_data.actors[actorGUID]
    
    -- Update threat
    actorData.current_threat = threatValue
    actorData.current_target = targetName
    actorData.threat_percent = threatPercent or 0
    
    -- Track in history
    local entry = {
        timestamp = GetTime(),
        threat = threatValue,
        percent = threatPercent,
        target = targetName,
    }
    
    table.insert(actorData.threat_history, entry)
    
    -- Trim if too many
    if #actorData.threat_history > self.config.max_snapshots then
        table.remove(actorData.threat_history, 1)
    end
    
    -- Check if at high threat (90%+)
    if threatPercent and threatPercent >= 90 then
        actorData.has_aggro = true
    else
        if actorData.has_aggro and threatPercent and threatPercent < 70 then
            actorData.times_lost_aggro = actorData.times_lost_aggro + 1
            actorData.has_aggro = false
        end
    end
    
    return true
end

function ThreatTrackingEngine:GetActorThreat(actorGUID)
    if not actorGUID or not self.threat_data.actors[actorGUID] then
        return nil
    end
    
    local actorData = self.threat_data.actors[actorGUID]
    
    return {
        name = actorData.name,
        guid = actorGUID,
        current_threat = actorData.current_threat,
        threat_percent = actorData.threat_percent,
        target = actorData.current_target,
        has_aggro = actorData.has_aggro,
        times_lost_aggro = actorData.times_lost_aggro,
    }
end

function ThreatTrackingEngine:GetHighThreatActors()
    local highThreat = {}
    
    for guid, actorData in pairs(self.threat_data.actors) do
        if actorData.threat_percent and actorData.threat_percent >= 70 then
            table.insert(highThreat, {
                name = actorData.name,
                guid = guid,
                threat = actorData.current_threat,
                percent = actorData.threat_percent,
                has_aggro = actorData.has_aggro,
            })
        end
    end
    
    -- Sort by threat descending
    table.sort(highThreat, function(a, b) return a.percent > b.percent end)
    
    return highThreat
end

function ThreatTrackingEngine:GetAggro()
    local aggro = {}
    
    for guid, actorData in pairs(self.threat_data.actors) do
        if actorData.has_aggro then
            table.insert(aggro, {
                name = actorData.name,
                guid = guid,
                threat = actorData.current_threat,
                target = actorData.current_target,
            })
        end
    end
    
    return aggro
end

function ThreatTrackingEngine:GetThreatTimeline(actorGUID, maxCount)
    if not actorGUID or not self.threat_data.actors[actorGUID] then
        return {}
    end
    
    if not maxCount then
        maxCount = 50
    end
    
    local actorData = self.threat_data.actors[actorGUID]
    local history = actorData.threat_history
    local startIdx = math.max(1, #history - maxCount + 1)
    
    local timeline = {}
    for i = startIdx, #history do
        table.insert(timeline, history[i])
    end
    
    return timeline
end

function ThreatTrackingEngine:GetThreatDistribution()
    local distribution = {}
    
    for guid, actorData in pairs(self.threat_data.actors) do
        table.insert(distribution, {
            name = actorData.name,
            guid = guid,
            threat = actorData.current_threat,
            percent = actorData.threat_percent or 0,
        })
    end
    
    -- Sort by threat descending
    table.sort(distribution, function(a, b) return a.threat > b.threat end)
    
    return distribution
end

function ThreatTrackingEngine:GetAverageThreat()
    local total = 0
    local count = 0
    
    for _, actorData in pairs(self.threat_data.actors) do
        if actorData.current_threat and actorData.current_threat > 0 then
            total = total + actorData.current_threat
            count = count + 1
        end
    end
    
    if count == 0 then
        return 0
    end
    
    return total / count
end

function ThreatTrackingEngine:GetMaxThreat()
    local maxThreat = 0
    
    for _, actorData in pairs(self.threat_data.actors) do
        if actorData.current_threat and actorData.current_threat > maxThreat then
            maxThreat = actorData.current_threat
        end
    end
    
    return maxThreat
end

function ThreatTrackingEngine:GetActorCount()
    local count = 0
    
    for _ in pairs(self.threat_data.actors) do
        count = count + 1
    end
    
    return count
end

function ThreatTrackingEngine:ClearData()
    self.threat_data.actors = {}
    self.threat_data.timeline = {}
    self:Log("All threat data cleared")
end

function ThreatTrackingEngine:GetStatus()
    local aggro = self:GetAggro()
    
    return {
        enabled = self.enabled,
        actor_count = self:GetActorCount(),
        actors_with_aggro = #aggro,
        max_threat = self:GetMaxThreat(),
        avg_threat = string.format("%.1f", self:GetAverageThreat()),
    }
end

function ThreatTrackingEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[ThreatTrackingEngine] " .. message)
    else
        print("[ThreatTrackingEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_THREAT1 = "/threat"
    SlashCmdList["THREAT"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "high" then
            local highThreat = ThreatTrackingEngine:GetHighThreatActors()
            print("High Threat Actors (70%+):")
            for _, actor in ipairs(highThreat) do
                print(string.format("  %s: %.1f%% (%s)", actor.name, actor.percent, actor.has_aggro and "AGGRO" or ""))
            end
        elseif cmd == "aggro" then
            local aggro = ThreatTrackingEngine:GetAggro()
            print("Actors With Aggro:")
            for _, actor in ipairs(aggro) do
                print("  " .. actor.name .. " on " .. (actor.target or "unknown"))
            end
        elseif cmd == "distribution" then
            local dist = ThreatTrackingEngine:GetThreatDistribution()
            print("Threat Distribution:")
            for i, actor in ipairs(dist) do
                print(string.format("  %d. %s: %.0f threat (%.1f%%)", i, actor.name, actor.threat, actor.percent))
            end
        elseif cmd == "clear" then
            ThreatTrackingEngine:ClearData()
            print("Threat data cleared")
        elseif cmd == "status" then
            local status = ThreatTrackingEngine:GetStatus()
            print("Threat Tracker:")
            for k, v in pairs(status) do
                print("  " .. k .. ": " .. tostring(v))
            end
        else
            print("Threat Tracker Commands:")
            print("  /threat high - Show high threat actors")
            print("  /threat aggro - Show actors with aggro")
            print("  /threat distribution - Show full distribution")
            print("  /threat status - Show system status")
            print("  /threat clear - Clear all data")
        end
    end
end

return ThreatTrackingEngine
