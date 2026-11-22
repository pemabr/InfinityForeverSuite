-- History Module
-- Loot history and award tracking

local InfinityDKPHistory = {}
_G.InfinityDKPHistory = InfinityDKPHistory

InfinityDKPHistory.awards = {}
InfinityDKPHistory.callbacks = {}

function InfinityDKPHistory:Initialize(db)
    if db.lootAwards == nil then db.lootAwards = {} end
    if type(db.lootAwards) ~= "table" then error("Invalid saved loot history") end
    self.awards = db.lootAwards
end

function InfinityDKPHistory:RecordAward(playerName, itemName, itemID, awardType, points, reason)
    local award = {
        player = playerName,
        item = itemName,
        itemID = itemID,
        type = awardType,
        points = points or 0,
        reason = reason or "Loot awarded",
        time = time(),
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
    
    table.insert(self.awards, award)
    self:TriggerCallback("award_recorded", playerName, itemName, points)
    
    return true
end

function InfinityDKPHistory:GetPlayerHistory(playerName, limit)
    limit = limit or 20
    local history = {}
    if limit <= 0 then return history end
    
    for i = #self.awards, 1, -1 do
        local award = self.awards[i]
        if award.player == playerName then
            table.insert(history, 1, award)
            if #history >= limit then break end
        end
    end
    
    return history
end

function InfinityDKPHistory:GetItemAwards(itemName, limit)
    limit = limit or 999
    local awards = {}
    if limit <= 0 then return awards end
    
    for i = #self.awards, 1, -1 do
        local award = self.awards[i]
        if award.item:lower() == itemName:lower() then
            table.insert(awards, 1, award)
            if #awards >= limit then break end
        end
    end
    
    return awards
end

function InfinityDKPHistory:GetRecentAwards(days)
    days = days or 7
    local cutoff = time() - (days * 86400)
    local recent = {}
    
    for _, award in ipairs(self.awards) do
        if award.time >= cutoff then
            table.insert(recent, award)
        end
    end
    
    return recent
end

function InfinityDKPHistory:GetPlayerSpent(playerName)
    local total = 0
    for _, award in ipairs(self.awards) do
        if award.player == playerName and not award.refund then
            total = total + (award.points or 0)
        end
    end
    return total
end

function InfinityDKPHistory:RefundAward(index)
    if _G.issecretvalue and _G.issecretvalue(index) then
        InfinityUtils:Warning("Protected loot award index.", "DKP")
        return false
    end
    if type(index) ~= "number" or index < 1 or index ~= math.floor(index) or index >= math.huge then
        InfinityUtils:Warning("Invalid loot award.", "DKP")
        return false
    end
    local award = self.awards[index]
    if _G.issecretvalue and _G.issecretvalue(award) then award = nil end
    if type(award) ~= "table" or (_G.issecretvalue and _G.issecretvalue(award.refund)) or award.refund then
        InfinityUtils:Warning("Loot award is missing or already refunded.", "DKP")
        return false
    end
    local engine, points = _G.InfinityDKPEngine, _G.InfinityDKPPoints
    if not engine or type(engine.db) ~= "table" or self.awards ~= engine.db.lootAwards
        or not points or type(engine.db.pointTransactions) ~= "table"
        or type(points.point_history) ~= "table" or points.point_history ~= engine.db.pointTransactions
        or type(points.LogTransaction) ~= "function" then
        InfinityUtils:Warning("DKP points or history are unavailable.", "DKP")
        return false
    end
    if _G.InfinityDKPGuildSync and InfinityDKPGuildSync.outgoing then
        InfinityUtils:Warning("Wait for the current DKP snapshot to finish.", "DKP")
        return false
    end
    local name, item, amount, kind = award.player, award.item, award.points, award.type
    if _G.issecretvalue and (issecretvalue(name) or issecretvalue(item) or issecretvalue(amount) or issecretvalue(kind)) then
        InfinityUtils:Warning("Loot award contains protected data.", "DKP")
        return false
    end
    if type(name) ~= "string" or name == "" or type(item) ~= "string" or item == ""
        or type(amount) ~= "number" or amount ~= amount or amount <= 0
        or amount > 1000000000 or amount ~= math.floor(amount)
        or (kind ~= "dkp" and kind ~= "manual") then
        InfinityUtils:Warning("Loot award cannot be refunded automatically.", "DKP")
        return false
    end
    local reason = "Refund: " .. item
    local pointType, change = kind == "dkp" and "dkp" or "gp", kind == "dkp" and amount or -amount
    if type(engine.AdjustDKP) ~= "function" or type(engine.RefundGP) ~= "function" then
        InfinityUtils:Warning("DKP points are unavailable.", "DKP")
        return false
    end
    award.refund = { amount = amount, pointType = pointType, time = time() }
    local success = kind == "dkp" and engine:AdjustDKP(name, amount, reason)
        or kind == "manual" and engine:RefundGP(name, amount, reason)
    if not success then
        award.refund = nil
        InfinityUtils:Warning("Refund failed; check the local player and point balance.", "DKP")
        return false
    end
    points:LogTransaction(name, pointType, change, reason)
    if _G.InfinityDKPGuildSync and type(InfinityDKPGuildSync.MarkSnapshotsStale) == "function" then
        InfinityDKPGuildSync:MarkSnapshotsStale("Local loot refund changed points")
    end
    self:TriggerCallback("award_refunded", name, item, amount, pointType)
    return true
end

function InfinityDKPHistory:ExportHistory(days)
    days = days or 999
    local cutoff = time() - (days * 86400)
    local export = ""
    
    for _, award in ipairs(self.awards) do
        if award.time >= cutoff then
            export = export .. string.format("%s | %s | %s | %s | %+d%s\n",
                award.timestamp, award.player, award.item, award.type, award.points,
                award.refund and " | refunded" or "")
        end
    end
    
    return export
end

function InfinityDKPHistory:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDKPHistory:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return InfinityDKPHistory
