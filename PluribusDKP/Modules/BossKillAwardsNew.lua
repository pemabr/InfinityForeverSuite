-- Boss Kill Awards System
-- Award EP/DKP points when bosses die in raids

local MODULE_NAME = "BossKillAwards"
local PluribusDKP = PluribusDKP or {}
local PluribusCore = PluribusCore or {}

PluribusDKP.BossKillAwards = {
    enabled = false,
    
    config = {
        boss_kill_awards_enabled = true,
        boss_kill_ep = 50,              -- Default 50 EP per boss kill
        clear_bonus_ep = 200,           -- Bonus for clearing raid
        clear_bonus_enabled = true,
        awards_only_during_raid = true,
        award_to_raid_members = true,
        exclude_afk_members = true
    },
    
    active_raid_bosses = {},
    raid_start_time = nil,
    raid_members = {},
    kill_history = {}
}

local BossKillAwards = PluribusDKP.BossKillAwards

function BossKillAwards:Initialize()
    if self.enabled then return end
    
    self.enabled = true
    
    if not PluribusDKP.db then
        PluribusDKP.db = {}
    end
    if not PluribusDKP.db.boss_kill_history then
        PluribusDKP.db.boss_kill_history = {}
    end
    
    if PluribusCore.Events then
        -- Register for combat events
        PluribusCore.Events:Register("encounter_start", function(boss_name, boss_id)
            BossKillAwards:OnEncounterStart(boss_name, boss_id)
        end)
        
        PluribusCore.Events:Register("encounter_end", function(boss_name, success, raid_members)
            BossKillAwards:OnEncounterEnd(boss_name, success, raid_members)
        end)
        
        PluribusCore.Events:Register("raid_end", function()
            BossKillAwards:OnRaidEnd()
        end)
        
        PluribusCore.Events:Register("raid_start", function()
            BossKillAwards:OnRaidStart()
        end)
    end
end

function BossKillAwards:OnRaidStart()
    self.raid_start_time = time()
    self.raid_members = {}
    self.active_raid_bosses = {}
    
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00ccffRaid session started - boss kill awards active|r")
    end
end

function BossKillAwards:OnEncounterStart(boss_name, boss_id)
    if not self.config.boss_kill_awards_enabled then return end
    if not self.raid_start_time then return end  -- No raid in progress
    
    self.active_raid_bosses[boss_id or boss_name] = {
        name = boss_name,
        id = boss_id,
        start_time = time(),
        defeated = false
    }
end

function BossKillAwards:OnEncounterEnd(boss_name, success, raid_members)
    if not self.config.boss_kill_awards_enabled then return end
    if not self.raid_start_time then return end  -- No raid in progress
    if not success then return end  -- Only award on success
    
    -- Award EP to raid members
    local award_amount = self.config.boss_kill_ep
    local members = raid_members or self:GetCurrentRaidMembers()
    
    local awarded_count = 0
    
    for _, member in ipairs(members) do
        if self:ShouldAwardMember(member) then
            if PluribusDKP.db and PluribusDKP.db.players then
                local player_data = PluribusDKP.db.players[member]
                if player_data then
                    player_data.balance = (player_data.balance or 0) + award_amount
                    
                    -- Log transaction
                    if PluribusDKP.db.transactions then
                        table.insert(PluribusDKP.db.transactions, {
                            timestamp = time(),
                            player = member,
                            amount = award_amount,
                            reason = string.format("Boss Kill - %s", boss_name or "Unknown"),
                            balance_after = player_data.balance,
                            source = "system",
                            type = "boss_kill",
                            boss_name = boss_name
                        })
                    end
                    
                    awarded_count = awarded_count + 1
                end
            end
        end
    end
    
    -- Log kill event
    table.insert(self.kill_history, {
        boss_name = boss_name,
        timestamp = time(),
        members_awarded = awarded_count,
        ep_per_member = award_amount
    })
    
    if PluribusDKP.db then
        PluribusDKP.db.boss_kill_history = self.kill_history
    end
    
    -- Notify in chat
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ff00%s defeated! %d %s awarded to %d players|r",
                boss_name or "Boss",
                award_amount,
                "EP",
                awarded_count
            )
        )
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("boss_kill_awarded", boss_name, award_amount, awarded_count)
    end
    
    -- Mark boss as defeated
    self.active_raid_bosses[boss_name or ""] = nil
end

function BossKillAwards:OnRaidEnd()
    if not self.config.boss_kill_awards_enabled then return end
    if not self.config.clear_bonus_enabled then return end
    
    -- Award clear bonus for all players who participated
    local members = self:GetCurrentRaidMembers()
    local bonus_amount = self.config.clear_bonus_ep
    local awarded_count = 0
    
    for _, member in ipairs(members) do
        if self:ShouldAwardMember(member) then
            if PluribusDKP.db and PluribusDKP.db.players then
                local player_data = PluribusDKP.db.players[member]
                if player_data then
                    player_data.balance = (player_data.balance or 0) + bonus_amount
                    
                    -- Log transaction
                    if PluribusDKP.db.transactions then
                        table.insert(PluribusDKP.db.transactions, {
                            timestamp = time(),
                            player = member,
                            amount = bonus_amount,
                            reason = "Raid Clear Bonus",
                            balance_after = player_data.balance,
                            source = "system",
                            type = "raid_clear_bonus"
                        })
                    end
                    
                    awarded_count = awarded_count + 1
                end
            end
        end
    end
    
    -- Notify in chat
    if DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            string.format("|cff00ff00Raid cleared! Clear bonus (%d %s) awarded to %d players|r",
                bonus_amount,
                "EP",
                awarded_count
            )
        )
    end
    
    if PluribusCore.Events then
        PluribusCore.Events:Fire("raid_clear_bonus_awarded", bonus_amount, awarded_count)
    end
    
    self.raid_start_time = nil
    self.raid_members = {}
    self.active_raid_bosses = {}
end

function BossKillAwards:ShouldAwardMember(member)
    if not member then return false end
    
    -- Don't award if excluding AFK and member is AFK
    if self.config.exclude_afk_members then
        -- Check if player is AFK (would need to integrate with presence system)
        -- For now, just check if player is in guild
        if not self:IsPlayerInGuild(member) then
            return false
        end
    end
    
    return true
end

function BossKillAwards:IsPlayerInGuild(player)
    if not PluribusDKP.db or not PluribusDKP.db.players then
        return false
    end
    
    return PluribusDKP.db.players[player] ~= nil
end

function BossKillAwards:GetCurrentRaidMembers()
    if not IsInRaid() then
        return {}
    end
    
    local members = {}
    local num_raid_members = GetNumGroupMembers()
    
    for i = 1, num_raid_members do
        local name = GetRaidRosterInfo(i)
        if name then
            table.insert(members, name)
        end
    end
    
    return members
end

function BossKillAwards:SetBossKillEP(ep_amount)
    if ep_amount < 1 or ep_amount > 1000 then
        print("|cffff0000Boss kill EP must be 1-1000|r")
        return false
    end
    
    self.config.boss_kill_ep = ep_amount
    print(string.format("|cff00ccffBoss kill EP set to %d|r", ep_amount))
    return true
end

function BossKillAwards:SetClearBonusEP(ep_amount)
    if ep_amount < 0 or ep_amount > 2000 then
        print("|cffff0000Clear bonus EP must be 0-2000|r")
        return false
    end
    
    self.config.clear_bonus_ep = ep_amount
    print(string.format("|cff00ccffRaid clear bonus EP set to %d|r", ep_amount))
    return true
end

function BossKillAwards:EnableBossKillAwards(enable)
    self.config.boss_kill_awards_enabled = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffBoss kill awards %s|r", status))
    return true
end

function BossKillAwards:EnableClearBonus(enable)
    self.config.clear_bonus_enabled = enable
    
    local status = enable and "enabled" or "disabled"
    print(string.format("|cff00ccffRaid clear bonus %s|r", status))
    return true
end

function BossKillAwards:PrintStatus()
    print("|cff00ccffBoss Kill Awards Status:|r")
    print(string.format("  Enabled: %s", self.config.boss_kill_awards_enabled and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Boss Kill EP: %d", self.config.boss_kill_ep))
    print(string.format("  Clear Bonus: %d %s", self.config.clear_bonus_ep, 
        self.config.clear_bonus_enabled and "" or "(disabled)"))
    print(string.format("  Raid Active: %s", self.raid_start_time and "|cff00ff00Yes|r" or "|cffff0000No|r"))
    print(string.format("  Total Kills Recorded: %d", #self.kill_history))
    print("")
end

function BossKillAwards:GetKillHistory(limit)
    limit = limit or 20
    
    local history = {}
    for i = #self.kill_history, math.max(1, #self.kill_history - limit + 1), -1 do
        table.insert(history, self.kill_history[i])
    end
    
    return history
end

function BossKillAwards:PrintKillHistory()
    local history = self:GetKillHistory(10)
    
    print("|cff00ccffRecent Boss Kills:|r")
    print("")
    
    for _, kill in ipairs(history) do
        local date_str = date("%H:%M:%S", kill.timestamp)
        print(string.format("[%s] %s - %d players, %d EP each",
            date_str,
            kill.boss_name or "Unknown",
            kill.members_awarded,
            kill.ep_per_member
        ))
    end
end

return PluribusDKP.BossKillAwards
