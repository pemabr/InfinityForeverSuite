-- TimelineAnalysisEngine.lua - Track damage and healing over time
-- Part of InfinityDetails addon suite
-- Provides timeline visualization data with 1-second buckets

local TimelineAnalysisEngine = {}
TimelineAnalysisEngine.enabled = false
TimelineAnalysisEngine.db = nil
TimelineAnalysisEngine.timeline_data = {}

-- Configuration
TimelineAnalysisEngine.config = {
    enabled = true,
    bucket_size = 1,  -- 1-second buckets
    max_timeline = 3600,  -- Max 1 hour
}

function TimelineAnalysisEngine:Initialize()
    if not InfinityCore then return end
    
    self.db = InfinityCore:GetDatabase("InfinityDetails")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.timeline_data then
        self.db.timeline_data = {
            damage = {},
            healing = {},
            start_time = 0,
        }
    end
    
    self.timeline_data = self.db.timeline_data
    self.enabled = true
    
    self:Log("Initialized timeline analysis engine")
end

function TimelineAnalysisEngine:RecordDamageEvent(damageAmount, timestamp)
    if not damageAmount or damageAmount <= 0 then
        return false
    end
    
    if not self.timeline_data.start_time or self.timeline_data.start_time == 0 then
        self.timeline_data.start_time = timestamp or GetTime()
    end
    
    local relativeTime = (timestamp or GetTime()) - self.timeline_data.start_time
    local bucketId = math.floor(relativeTime / self.config.bucket_size)
    
    if not self.timeline_data.damage[bucketId] then
        self.timeline_data.damage[bucketId] = {
            time = bucketId * self.config.bucket_size,
            total = 0,
            count = 0,
            max = 0,
        }
    end
    
    self.timeline_data.damage[bucketId].total = self.timeline_data.damage[bucketId].total + damageAmount
    self.timeline_data.damage[bucketId].count = self.timeline_data.damage[bucketId].count + 1
    
    if damageAmount > self.timeline_data.damage[bucketId].max then
        self.timeline_data.damage[bucketId].max = damageAmount
    end
    
    return true
end

function TimelineAnalysisEngine:RecordHealingEvent(healingAmount, timestamp)
    if not healingAmount or healingAmount <= 0 then
        return false
    end
    
    if not self.timeline_data.start_time or self.timeline_data.start_time == 0 then
        self.timeline_data.start_time = timestamp or GetTime()
    end
    
    local relativeTime = (timestamp or GetTime()) - self.timeline_data.start_time
    local bucketId = math.floor(relativeTime / self.config.bucket_size)
    
    if not self.timeline_data.healing[bucketId] then
        self.timeline_data.healing[bucketId] = {
            time = bucketId * self.config.bucket_size,
            total = 0,
            count = 0,
            max = 0,
        }
    end
    
    self.timeline_data.healing[bucketId].total = self.timeline_data.healing[bucketId].total + healingAmount
    self.timeline_data.healing[bucketId].count = self.timeline_data.healing[bucketId].count + 1
    
    if healingAmount > self.timeline_data.healing[bucketId].max then
        self.timeline_data.healing[bucketId].max = healingAmount
    end
    
    return true
end

function TimelineAnalysisEngine:GetDamageTimeline(startBucket, endBucket)
    if not startBucket then
        startBucket = 0
    end
    
    if not endBucket then
        endBucket = 1000  -- Default 1000 buckets
    end
    
    local timeline = {}
    
    for i = startBucket, endBucket do
        if self.timeline_data.damage[i] then
            table.insert(timeline, self.timeline_data.damage[i])
        end
    end
    
    return timeline
end

function TimelineAnalysisEngine:GetHealingTimeline(startBucket, endBucket)
    if not startBucket then
        startBucket = 0
    end
    
    if not endBucket then
        endBucket = 1000  -- Default 1000 buckets
    end
    
    local timeline = {}
    
    for i = startBucket, endBucket do
        if self.timeline_data.healing[i] then
            table.insert(timeline, self.timeline_data.healing[i])
        end
    end
    
    return timeline
end

function TimelineAnalysisEngine:GetPeakDamageSecond()
    local maxDamage = 0
    local peakSecond = 0
    
    for bucketId, bucket in pairs(self.timeline_data.damage) do
        if bucket.total > maxDamage then
            maxDamage = bucket.total
            peakSecond = bucketId
        end
    end
    
    return peakSecond, maxDamage
end

function TimelineAnalysisEngine:GetPeakHealingSecond()
    local maxHealing = 0
    local peakSecond = 0
    
    for bucketId, bucket in pairs(self.timeline_data.healing) do
        if bucket.total > maxHealing then
            maxHealing = bucket.total
            peakSecond = bucketId
        end
    end
    
    return peakSecond, maxHealing
end

function TimelineAnalysisEngine:GetAverageDamagePerSecond()
    local totalDamage = 0
    local bucketCount = 0
    
    for _, bucket in pairs(self.timeline_data.damage) do
        totalDamage = totalDamage + bucket.total
        bucketCount = bucketCount + 1
    end
    
    if bucketCount == 0 then
        return 0
    end
    
    return totalDamage / bucketCount
end

function TimelineAnalysisEngine:GetAverageHealingPerSecond()
    local totalHealing = 0
    local bucketCount = 0
    
    for _, bucket in pairs(self.timeline_data.healing) do
        totalHealing = totalHealing + bucket.total
        bucketCount = bucketCount + 1
    end
    
    if bucketCount == 0 then
        return 0
    end
    
    return totalHealing / bucketCount
end

function TimelineAnalysisEngine:GetTotalDamage()
    local total = 0
    
    for _, bucket in pairs(self.timeline_data.damage) do
        total = total + bucket.total
    end
    
    return total
end

function TimelineAnalysisEngine:GetTotalHealing()
    local total = 0
    
    for _, bucket in pairs(self.timeline_data.healing) do
        total = total + bucket.total
    end
    
    return total
end

function TimelineAnalysisEngine:GetEncounterDuration()
    local maxBucket = 0
    
    for bucketId, _ in pairs(self.timeline_data.damage) do
        if bucketId > maxBucket then
            maxBucket = bucketId
        end
    end
    
    for bucketId, _ in pairs(self.timeline_data.healing) do
        if bucketId > maxBucket then
            maxBucket = bucketId
        end
    end
    
    return maxBucket * self.config.bucket_size
end

function TimelineAnalysisEngine:GetDamageBucketCount()
    local count = 0
    
    for _ in pairs(self.timeline_data.damage) do
        count = count + 1
    end
    
    return count
end

function TimelineAnalysisEngine:GetHealingBucketCount()
    local count = 0
    
    for _ in pairs(self.timeline_data.healing) do
        count = count + 1
    end
    
    return count
end

function TimelineAnalysisEngine:ClearData()
    self.timeline_data.damage = {}
    self.timeline_data.healing = {}
    self.timeline_data.start_time = 0
    self:Log("All timeline data cleared")
end

function TimelineAnalysisEngine:GetStatus()
    return {
        enabled = self.enabled,
        encounter_duration = self:GetEncounterDuration(),
        damage_buckets = self:GetDamageBucketCount(),
        healing_buckets = self:GetHealingBucketCount(),
        total_damage = self:GetTotalDamage(),
        total_healing = self:GetTotalHealing(),
        avg_dps = self:GetAverageDamagePerSecond(),
        avg_hps = self:GetAverageHealingPerSecond(),
    }
end

function TimelineAnalysisEngine:Log(message)
    if InfinityCore and InfinityCore.Log then
        InfinityCore.Log("[TimelineAnalysisEngine] " .. message)
    else
        print("[TimelineAnalysisEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_TIMELINE1 = "/timeline"
    SlashCmdList["TIMELINE"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "dps" then
            local peakSecond, peakDamage = TimelineAnalysisEngine:GetPeakDamageSecond()
            print("Damage Timeline:")
            print("  Peak: " .. peakSecond .. "s (" .. string.format("%.0f", peakDamage) .. " damage)")
            print("  Average: " .. string.format("%.0f", TimelineAnalysisEngine:GetAverageDamagePerSecond()) .. " dps")
            print("  Total: " .. string.format("%.0f", TimelineAnalysisEngine:GetTotalDamage()))
        elseif cmd == "hps" then
            local peakSecond, peakHealing = TimelineAnalysisEngine:GetPeakHealingSecond()
            print("Healing Timeline:")
            print("  Peak: " .. peakSecond .. "s (" .. string.format("%.0f", peakHealing) .. " healing)")
            print("  Average: " .. string.format("%.0f", TimelineAnalysisEngine:GetAverageHealingPerSecond()) .. " hps")
            print("  Total: " .. string.format("%.0f", TimelineAnalysisEngine:GetTotalHealing()))
        elseif cmd == "clear" then
            TimelineAnalysisEngine:ClearData()
            print("Timeline data cleared")
        elseif cmd == "status" then
            local status = TimelineAnalysisEngine:GetStatus()
            print("Timeline Analysis:")
            print("  Duration: " .. string.format("%.1f", status.encounter_duration) .. "s")
            print("  Damage Buckets: " .. status.damage_buckets)
            print("  Healing Buckets: " .. status.healing_buckets)
            print("  Total Damage: " .. string.format("%.0f", status.total_damage))
            print("  Total Healing: " .. string.format("%.0f", status.total_healing))
            print("  Avg DPS: " .. string.format("%.1f", status.avg_dps))
            print("  Avg HPS: " .. string.format("%.1f", status.avg_hps))
        else
            print("Timeline Analysis Commands:")
            print("  /timeline dps - Show damage timeline stats")
            print("  /timeline hps - Show healing timeline stats")
            print("  /timeline status - Show system status")
            print("  /timeline clear - Clear all data")
        end
    end
end

return TimelineAnalysisEngine
