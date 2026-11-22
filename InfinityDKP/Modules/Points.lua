-- Points Module
-- DKP point administration and management

local InfinityDKPPoints = {}
_G.InfinityDKPPoints = InfinityDKPPoints

InfinityDKPPoints.point_history = {}
InfinityDKPPoints.callbacks = {}

function InfinityDKPPoints:LogTransaction(playerName, pointType, amount, reason)
    if not playerName or not pointType or not amount then return false end
    
    local transaction = {
        player = playerName,
        type = pointType,
        amount = amount,
        reason = reason or "No reason",
        time = GetTime(),
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
    
    table.insert(self.point_history, transaction)
    self:TriggerCallback("transaction_logged", playerName, pointType, amount)
    
    return true
end

function InfinityDKPPoints:GetHistory(playerName, limit)
    limit = limit or 50
    local history = {}
    
    for i = #self.point_history, math.max(1, #self.point_history - limit + 1), -1 do
        local trans = self.point_history[i]
        if not playerName or trans.player == playerName then
            table.insert(history, 1, trans)
        end
    end
    
    return history
end

function InfinityDKPPoints:ExportHistory()
    local export = ""
    for _, trans in ipairs(self.point_history) do
        export = export .. string.format("%s | %s | %s | %+d | %s\n",
            trans.timestamp, trans.player, trans.type, trans.amount, trans.reason)
    end
    return export
end

function InfinityDKPPoints:RegisterCallback(func)
    if type(func) ~= "function" then return end
    table.insert(self.callbacks, func)
end

function InfinityDKPPoints:TriggerCallback(event, ...)
    for _, callback in ipairs(self.callbacks) do
        pcall(callback, event, ...)
    end
end

return InfinityDKPPoints
