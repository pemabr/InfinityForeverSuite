-- GatherSkillTrackerEngine.lua - Track gathering skill progression
-- Part of PluribusGather addon suite
-- Monitors and records gathering skill levels and progress for all professions

local GatherSkillTrackerEngine = {}
GatherSkillTrackerEngine.enabled = false
GatherSkillTrackerEngine.db = nil
GatherSkillTrackerEngine.professions = {}

-- Configuration
GatherSkillTrackerEngine.config = {
    enabled = true,
    track_herbalism = true,
    track_mining = true,
    track_fishing = true,
    track_skinning = true,
}

-- Profession tracking
GatherSkillTrackerEngine.PROFESSION_HERBALISM = 1
GatherSkillTrackerEngine.PROFESSION_MINING = 2
GatherSkillTrackerEngine.PROFESSION_FISHING = 3
GatherSkillTrackerEngine.PROFESSION_SKINNING = 4

function GatherSkillTrackerEngine:Initialize()
    if not PluribusCore then return end
    
    self.db = PluribusCore:GetDatabase("PluribusGather")
    if not self.db then
        self.db = {}
    end
    
    if not self.db.skill_data then
        self.db.skill_data = {
            herbalism = { level = 0, max = 0, experience = 0 },
            mining = { level = 0, max = 0, experience = 0 },
            fishing = { level = 0, max = 0, experience = 0 },
            skinning = { level = 0, max = 0, experience = 0 },
        }
    end
    
    self.professions = self.db.skill_data
    self.enabled = true
    
    self:Log("Initialized skill tracker engine")
end

function GatherSkillTrackerEngine:AddSkillExperience(professionID, amount)
    if not self.professions then
        return false
    end
    
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return false
    end
    
    self.professions[profession].experience = self.professions[profession].experience + (amount or 1)
    
    self:Log(profession .. " experience increased by " .. (amount or 1) .. " (total: " .. self.professions[profession].experience .. ")")
    
    return true
end

function GatherSkillTrackerEngine:SetSkillLevel(professionID, level, maxLevel)
    if not self.professions then
        return false
    end
    
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return false
    end
    
    self.professions[profession].level = level
    self.professions[profession].max = maxLevel or level
    
    self:Log(profession .. " skill set to " .. level .. "/" .. (maxLevel or level))
    
    return true
end

function GatherSkillTrackerEngine:TrackGatherEvent(professionID, nodeType, nodeLevel, success)
    if not self.professions then
        return false
    end
    
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return false
    end
    
    if not self.professions[profession].gather_events then
        self.professions[profession].gather_events = {}
    end
    
    local event = {
        timestamp = GetTime(),
        node_type = nodeType,
        node_level = nodeLevel,
        success = success,
    }
    
    table.insert(self.professions[profession].gather_events, event)
    
    -- Calculate experience gain (1 XP per level difference, bonus for harder nodes)
    local xp = 1
    if nodeLevel > self.professions[profession].level then
        xp = xp + (nodeLevel - self.professions[profession].level) * 5
    end
    
    if success then
        self:AddSkillExperience(professionID, xp)
    end
    
    return true
end

function GatherSkillTrackerEngine:GetSkillLevel(professionID)
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return 0, 0
    end
    
    return self.professions[profession].level, self.professions[profession].max
end

function GatherSkillTrackerEngine:GetSkillProgress(professionID)
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return 0, 0
    end
    
    return self.professions[profession].experience, 0
end

function GatherSkillTrackerEngine:GetGatherStats(professionID)
    if not self.professions then
        return nil
    end
    
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return nil
    end
    
    local prof = self.professions[profession]
    local events = prof.gather_events or {}
    
    local stats = {
        profession = profession,
        level = prof.level,
        max = prof.max,
        experience = prof.experience,
        total_gathers = #events,
        successful_gathers = 0,
        failed_gathers = 0,
        success_rate = 0,
    }
    
    for _, event in ipairs(events) do
        if event.success then
            stats.successful_gathers = stats.successful_gathers + 1
        else
            stats.failed_gathers = stats.failed_gathers + 1
        end
    end
    
    if stats.total_gathers > 0 then
        stats.success_rate = (stats.successful_gathers / stats.total_gathers) * 100
    end
    
    return stats
end

function GatherSkillTrackerEngine:GetAllSkillStats()
    local stats = {}
    
    if self.professions.herbalism then
        table.insert(stats, self:GetGatherStats(self.PROFESSION_HERBALISM))
    end
    if self.professions.mining then
        table.insert(stats, self:GetGatherStats(self.PROFESSION_MINING))
    end
    if self.professions.fishing then
        table.insert(stats, self:GetGatherStats(self.PROFESSION_FISHING))
    end
    if self.professions.skinning then
        table.insert(stats, self:GetGatherStats(self.PROFESSION_SKINNING))
    end
    
    return stats
end

function GatherSkillTrackerEngine:ResetSkill(professionID)
    local profession = self:_GetProfessionName(professionID)
    if not profession or not self.professions[profession] then
        return false
    end
    
    self.professions[profession] = {
        level = 0,
        max = 0,
        experience = 0,
        gather_events = {},
    }
    
    self:Log(profession .. " skill reset")
    
    return true
end

function GatherSkillTrackerEngine:ExportSkillData(format)
    if not format then
        format = "json"
    end
    
    if format == "json" then
        return self.professions
    elseif format == "csv" then
        local csv = "Profession,Level,MaxLevel,Experience,TotalGathers,SuccessfulGathers,FailedGathers,SuccessRate\n"
        
        local stats = self:GetAllSkillStats()
        for _, stat in ipairs(stats) do
            if stat then
                csv = csv .. stat.profession .. "," .. stat.level .. "," .. stat.max .. ","
                csv = csv .. stat.experience .. "," .. stat.total_gathers .. ","
                csv = csv .. stat.successful_gathers .. "," .. stat.failed_gathers .. ","
                csv = csv .. math.floor(stat.success_rate * 100) / 100 .. "\n"
            end
        end
        
        return csv
    end
    
    return nil
end

function GatherSkillTrackerEngine:_GetProfessionName(professionID)
    if professionID == self.PROFESSION_HERBALISM then
        return "herbalism"
    elseif professionID == self.PROFESSION_MINING then
        return "mining"
    elseif professionID == self.PROFESSION_FISHING then
        return "fishing"
    elseif professionID == self.PROFESSION_SKINNING then
        return "skinning"
    end
    
    return nil
end

function GatherSkillTrackerEngine:GetStatus()
    local stats = self:GetAllSkillStats()
    
    return {
        enabled = self.enabled,
        professions_tracked = #stats,
        total_experience = self:_GetTotalExperience(),
        total_gathers = self:_GetTotalGathers(),
    }
end

function GatherSkillTrackerEngine:_GetTotalExperience()
    local total = 0
    for _, prof in pairs(self.professions) do
        total = total + (prof.experience or 0)
    end
    return total
end

function GatherSkillTrackerEngine:_GetTotalGathers()
    local total = 0
    for _, prof in pairs(self.professions) do
        if prof.gather_events then
            total = total + #prof.gather_events
        end
    end
    return total
end

function GatherSkillTrackerEngine:Log(message)
    if PluribusCore and PluribusCore.Log then
        PluribusCore.Log("[GatherSkillTrackerEngine] " .. message)
    else
        print("[GatherSkillTrackerEngine] " .. message)
    end
end

-- Register admin commands
if not IsTestingLua then
    SLASH_GATHERSKILL1 = "/gatherskill"
    SlashCmdList["GATHERSKILL"] = function(msg)
        local cmd, args = msg:match("^(%S*)%s*(.*)$")
        cmd = cmd or ""
        
        if cmd == "set" then
            local prof, level, max = args:match("(%S+)%s+(%d+)%s*(%d*)")
            if prof and level then
                local profID = 0
                if prof == "herb" or prof == "herbalism" then
                    profID = GatherSkillTrackerEngine.PROFESSION_HERBALISM
                elseif prof == "ore" or prof == "mining" then
                    profID = GatherSkillTrackerEngine.PROFESSION_MINING
                elseif prof == "fish" or prof == "fishing" then
                    profID = GatherSkillTrackerEngine.PROFESSION_FISHING
                elseif prof == "skin" or prof == "skinning" then
                    profID = GatherSkillTrackerEngine.PROFESSION_SKINNING
                end
                
                if profID > 0 then
                    GatherSkillTrackerEngine:SetSkillLevel(profID, tonumber(level), tonumber(max) or tonumber(level))
                    print("Skill set")
                end
            end
        elseif cmd == "stats" then
            local stats = GatherSkillTrackerEngine:GetAllSkillStats()
            print("Gathering Skills:")
            for _, stat in ipairs(stats) do
                if stat then
                    print("  " .. stat.profession .. ": " .. stat.level .. "/" .. stat.max .. 
                          " (" .. stat.experience .. " XP) - " .. stat.successful_gathers .. "/" .. stat.total_gathers .. " gathers")
                end
            end
        elseif cmd == "status" then
            local status = GatherSkillTrackerEngine:GetStatus()
            print("Skill Tracker Status:")
            print("  Professions: " .. status.professions_tracked)
            print("  Total experience: " .. status.total_experience)
            print("  Total gathers: " .. status.total_gathers)
        else
            print("Skill Tracker Commands:")
            print("  /gatherskill set [prof] [level] [max] - Set skill level")
            print("  /gatherskill stats - Show all skill stats")
            print("  /gatherskill status - Show overall status")
        end
    end
end

return GatherSkillTrackerEngine
