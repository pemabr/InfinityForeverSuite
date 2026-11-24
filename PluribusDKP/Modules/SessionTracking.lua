-- Session Tracking System
-- Track raid sessions and when they occur

local MODULE_NAME = "SessionTracking"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.Sessions = {
    enabled = false,
    
    config = {
        auto_detect_raids = true,
        track_dungeons = true,
        track_world_pvp = false,
        min_raid_size = 10,  -- Minimum group size to count as "raid"
        session_timeout = 3600  -- Consider session over if no activity for 1 hour
    },
    
    current_session = nil,
    session_history = {},
    session_members = {},
    session_loots = {}
}

local Sessions = PluribusDKP.Sessions

function Sessions:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.session_history then
        PluribusDKP.db.session_history = {}
    end
    
    self.session_history = PluribusDKP.db.session_history
    
    if PluribusCore.Events then
        PluribusCore.Events:Register("raid_start", function()
            Sessions:OnRaidStart()
        end)
        
        PluribusCore.Events:Register("raid_end", function()
            Sessions:OnRaidEnd()
        end)
        
        PluribusCore.Events:Register("loot_awarded", function(player, item, award_type, gp)
            Sessions:RecordLoot(player, item, award_type, gp)
        end)
        
        PluribusCore.Events:Register("boss_killed", function(boss_name)
            Sessions:RecordBossKill(boss_name)
        end)
    end
end

function Sessions:OnRaidStart()
    if not self.config.auto_detect_raids then return end
    
    local raid_name = GetRaidName() or "Unknown Raid"
    
    self.current_session = {
        id = "SESSION_" .. tostring(time()),
        name = raid_name,
        type = self:DetectRaidType(),
        start_time = time(),
        end_time = nil,
        members = {},
        member_count = 0,
        loot_count = 0,
        boss_kills = {},
        total_gp_awarded = 0,
        total_ep_awarded = 0,
        notes = ""
    }
    
    -- Record initial members
    self:RecordSessionMembers()
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ccffRaid session started: %s (%d members)|r",
                raid_name,
                self.current_session.member_count
            )
        )
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("session_started", self.current_session.id, raid_name)
    end
end

function Sessions:OnRaidEnd()
    if not self.current_session then return end
    
    self.current_session.end_time = time()
    local duration = self.current_session.end_time - self.current_session.start_time
    
    -- Save session
    table.insert(self.session_history, self.current_session)
    
    if PluribusDKP.db then
        PluribusDKP.db.session_history = self.session_history
    end
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ccffRaid session ended: %d members, %d loot items, %d boss kills, duration: %02dh%02dm|r",
                self.current_session.member_count,
                self.current_session.loot_count,
                #self.current_session.boss_kills,
                math.floor(duration / 3600),
                math.floor((duration % 3600) / 60)
            )
        )
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("session_ended", self.current_session.id, duration)
    end
    
    self.current_session = nil
end

function Sessions:DetectRaidType()
    local zone_name = GetZoneText()
    
    if zone_name:find("Molten Core") or zone_name:find("MC") then
        return "Molten Core"
    elseif zone_name:find("Blackwing Lair") or zone_name:find("BWL") then
        return "Blackwing Lair"
    elseif zone_name:find("World Bosses") then
        return "World Boss"
    elseif zone_name:find("Dungeon") or IsInInstance() then
        return "Dungeon"
    else
        return "Raid"
    end
end

function Sessions:RecordSessionMembers()
    if not self.current_session then return end
    
    local members = {}
    
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name = GetRaidRosterInfo(i)
            if name then
                table.insert(members, {
                    name = name,
                    join_time = time(),
                    leave_time = nil,
                    loot_earned = {}
                })
            end
        end
    elseif IsInGroup() then
        for i = 1, GetNumGroupMembers() do
            local name = GetGroupMemberName(i)
            if name then
                table.insert(members, {
                    name = name,
                    join_time = time(),
                    leave_time = nil,
                    loot_earned = {}
                })
            end
        end
    end
    
    self.current_session.members = members
    self.current_session.member_count = #members
end

function Sessions:RecordLoot(player, item, award_type, gp_cost)
    if not self.current_session then return end
    
    table.insert(self.current_session.loot_count, {
        player = player,
        item = item,
        award_type = award_type,
        gp_cost = gp_cost,
        timestamp = time()
    })
    
    self.current_session.total_gp_awarded = (self.current_session.total_gp_awarded or 0) + (gp_cost or 0)
    
    -- Track per-member loot
    for _, member in ipairs(self.current_session.members) do
        if member.name == player then
            table.insert(member.loot_earned, {
                item = item,
                award_type = award_type,
                gp = gp_cost
            })
            break
        end
    end
end

function Sessions:RecordBossKill(boss_name)
    if not self.current_session then return end
    
    table.insert(self.current_session.boss_kills, {
        name = boss_name,
        timestamp = time()
    })
end

function Sessions:GetCurrentSession()
    return self.current_session
end

function Sessions:GetSessionDuration()
    if not self.current_session then return 0 end
    
    local end_time = self.current_session.end_time or time()
    return end_time - self.current_session.start_time
end

function Sessions:GetSessionInfo(session_id)
    if not session_id then
        return self.current_session
    end
    
    for _, session in ipairs(self.session_history) do
        if session.id == session_id then
            return session
        end
    end
    
    return nil
end

function Sessions:GetSessionsForDate(date_str)
    local sessions = {}
    
    for _, session in ipairs(self.session_history) do
        local session_date = date("%Y-%m-%d", session.start_time)
        if session_date == date_str then
            table.insert(sessions, session)
        end
    end
    
    return sessions
end

function Sessions:GetSessionsByPlayer(player_name)
    local sessions = {}
    
    for _, session in ipairs(self.session_history) do
        for _, member in ipairs(session.members) do
            if member.name == player_name then
                table.insert(sessions, session)
                break
            end
        end
    end
    
    return sessions
end

function Sessions:PrintCurrentSession()
    if not self.current_session then
        print("|cffff9900No active session|r")
        return
    end
    
    local duration = self:GetSessionDuration()
    
    print("|cff00ccffCurrent Session:|r")
    print(string.format("  ID: %s", self.current_session.id))
    print(string.format("  Name: %s", self.current_session.name))
    print(string.format("  Type: %s", self.current_session.type))
    print(string.format("  Members: %d", self.current_session.member_count))
    print(string.format("  Duration: %02dh%02dm%02ds",
        math.floor(duration / 3600),
        math.floor((duration % 3600) / 60),
        duration % 60
    ))
    print(string.format("  Loot Awarded: %d items", self.current_session.loot_count))
    print(string.format("  Boss Kills: %d", #self.current_session.boss_kills))
    print(string.format("  Total GP: %d", self.current_session.total_gp_awarded))
    print("")
end

function Sessions:PrintSessionHistory(limit)
    limit = limit or 10
    
    if #self.session_history == 0 then
        print("|cffff9900No session history|r")
        return
    end
    
    print("|cff00ccffRecent Sessions:|r")
    print("")
    
    for i = #self.session_history, math.max(1, #self.session_history - limit + 1), -1 do
        local session = self.session_history[i]
        local start_date = date("%m-%d %H:%M", session.start_time)
        local duration = session.end_time and (session.end_time - session.start_time) or 0
        
        print(string.format("[%s] %s - %d members, %d loot, %d kills (%02dh%02dm)",
            start_date,
            session.name or "Unknown",
            session.member_count,
            session.loot_count,
            #session.boss_kills,
            math.floor(duration / 3600),
            math.floor((duration % 3600) / 60)
        ))
    end
    
    print("")
end

function Sessions:PrintSessionMembers(session_id)
    local session = self:GetSessionInfo(session_id)
    if not session then
        print("|cffff0000Session not found|r")
        return
    end
    
    print(string.format("|cff00ccffMembers of %s:|r", session.name))
    print("")
    
    for _, member in ipairs(session.members) do
        local loot_count = #member.loot_earned
        local loot_gp = 0
        
        for _, loot in ipairs(member.loot_earned) do
            loot_gp = loot_gp + (loot.gp or 0)
        end
        
        print(string.format("  %s - %d items (%d GP)",
            member.name,
            loot_count,
            loot_gp
        ))
    end
    
    print("")
end

function Sessions:PrintStatus()
    print("|cff00ccffSession Tracking Status:|r")
    print(string.format("  Enabled: %s", self.enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Auto-detect: %s", self.config.auto_detect_raids and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Current Session: %s", self.current_session and "|cff00ff00Active|r" or "|cffff0000Inactive|r"))
    print(string.format("  Sessions Recorded: %d", #self.session_history))
    print("")
end

return PluribusDKP.Sessions
