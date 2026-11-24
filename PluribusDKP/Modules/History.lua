-- History Module
-- Loot history and award tracking

local PluribusDKPHistory = {}
_G.PluribusDKPHistory = PluribusDKPHistory

PluribusDKPHistory.awards = {}
PluribusDKPHistory.callbacks = {}

function PluribusDKPHistory:RecordAward(playerName, itemName, itemID, awardType, points, reason)
    local award = {
        player = playerName,
        item = itemName,
        itemID = itemID,
        type = awardType,
        points = points or 0,
        reason = reason or "Loot awarded",
        time = GetTime(),
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
    
    table.insert(self.awards, award)
    self:TriggerCallback("award_recorded", playerName, itemName, points)
    
    return true
end

function PluribusDKPHistory:GetPlayerHistory(playerName, limit)
    limit = limit or 20
    local history = {}
    
    for i = #self.awards, math.max(1, #self.awards - limit + 1), -1 do
        local award = self.awards[i]
        if award.player == playerName then
            table.insert(history, 1, award)
        end
    end
    
    return history
end

function PluribusDKPHistory:GetItemAwards(itemName, limit)
    limit = limit or 999
    local awards = {}
    
    for i = #self.awards, math.max(1, #self.awards - limit + 1), -1 do
        local award = self.awards[i]
        if award.item:lower() == itemName:lower() then
            table.insert(awards, 1, award)
        end
    end
    
    return awards
end

function PluribusDKPHistory:GetRecentAwards(days)
    days = days or 7
    local cutoff = GetTime() - (days * 86400)
    local recent = {}
    
    for _, award in ipairs(self.awards) do
        if award.time >= cutoff then
            table.insert(recent, award)
        end
    end
    
    return recent
end

function PluribusDKPHistory:GetPlayerSpent(playerName)
    local total = 0
    for _, award in ipairs(self.awards) do
        if award.player == playerName then
            total = total + (award.points or 0)
        end
    end
    return total
end

function PluribusDKPHistory:ExportHistory(days)
    days = days or 999
    local cutoff = GetTime() - (days * 86400)
    local export = ""
    
    for _, award in ipairs(self.awards) do
        if award.time >= cutoff then
            export = export .. string.format("%s | %s | %s | %s | %+d\n",
                award.timestamp, award.player, award.item, award.type, award.points)
        end
    end
    
    return export
end

function PluribusDKPHistory:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function PluribusDKPHistory:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return PluribusDKPHistory
